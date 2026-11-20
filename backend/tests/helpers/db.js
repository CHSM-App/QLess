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

  reset() {
    this.calls = [];
    this.respond = () => [];
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
      const call = { kind, target, inputs: req.inputs };
      mockDb.calls.push(call);
      const answer = await mockDb.respond(call);
      if (Array.isArray(answer)) return { recordset: answer, recordsets: [answer], rowsAffected: [answer.length] };
      return answer || { recordset: [], recordsets: [[]], rowsAffected: [0] };
    };
    req.execute = run('execute');
    req.query = run('query');
    req.batch = run('batch');
    return req;
  },

  ensureConnected: () => Promise.resolve(),
  connected: true,
};

module.exports = { mockDb };
