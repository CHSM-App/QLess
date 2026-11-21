/**
 * Scripted stand-in for src/db.js (the mssql pool).
 *
 * Routes call db.request().input(...).execute('sp_x') or .query(sql). Instead
 * of queueing results in call order (fragile: one extra call shifts every
 * later answer), a suite sets ONE responder that answers by what was called:
 *
 *   mockDb.respond = ({ target, inputs }) => {
 *     if (target === 'sp_appointment' && inputs.operation === 'NEXT_SESSION')
 *       return [{ success: 1, token: 'fcm-token' }];
 *     return [];
 *   };
 *
 * The responder returns the recordset (an array), a full result object
 * ({ recordset, recordsets, rowsAffected }), or throws to simulate a DB error.
 * Every call is recorded in mockDb.calls for assertions.
 */
const mockDb = {
  calls: [],
  respond: () => [],

  owns: true,
  staffDoctorId: 1, // the doctor a receptionist token works for (ownStaff lookup)
  doctorActive: true, // false = an admin blocked that doctor (active_status 1)

  reset() {
    this.calls = [];
    this.respond = () => [];
    this.owns = true;
    this.staffDoctorId = 1;
    this.doctorActive = true;
  },

  /** Calls made to one stored procedure (or query text containing `target`). */
  callsTo(target, operation) {
    return this.calls.filter((c) =>
      (c.target === target || (c.kind !== 'execute' && c.target.includes(target))) &&
      (operation === undefined || c.inputs.operation === operation));
  },

  request() {
    const req = { inputs: {} };
    // .input(name, value) and .input(name, sql.Type, value) are both used.
    req.input = (name, typeOrValue, value) => {
      req.inputs[name] = value === undefined ? typeOrValue : value;
      return req;
    };
    req.output = req.input;
    const run = (kind) => async (target) => {
      // ownership checks (src/middleware/ownPatient.js): answered by the
      // mockDb.owns switch, not recorded, so suites keep their call counts
      if (kind === 'query' && String(target).startsWith('/* ownership */')) {
        return { recordset: mockDb.owns ? [{ ok: 1, doctor_id: mockDb.staffDoctorId, active_status: mockDb.doctorActive ? 0 : 1 }] : [], recordsets: [], rowsAffected: [0] };
      }
      const call = { kind, target, inputs: req.inputs };
      mockDb.calls.push(call);
      const answer = await mockDb.respond(call);
      if (Array.isArray(answer)) return { recordset: answer, recordsets: [answer], rowsAffected: [answer.length] };
      return answer || { recordset: [], recordsets: [[]], rowsAffected: [0] };
    };
    req.execute = run('execute');
    req.query = run('query');
    req.batch = run('batch');
    // .run(queries) runs a former stored procedure's SQL (src/queries/*.js);
    // recorded under that procedure's name, like the .execute() it replaced.
    req.run = (queries) => run('execute')(queries.procedure);
    return req;
  },

  ensureConnected: () => Promise.resolve(),
  connected: true,
};

module.exports = { mockDb };
