// SQL moved from the stored procedure sp_slot_today_count (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/slotTodayCount'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'sp_slot_today_count',
  params: [
    { name: 'slot_id', type: 'INT', default: null },
  ],
  ops: {

  },
  // any other @operation value (the procedure ran none of its branches)
  other: `
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS cnt
    FROM appointments
    WHERE slot_id = @slot_id
      AND appointment_date = CAST(GETDATE() AS DATE)
      AND LOWER(status) IN ('booked', 'in_progress');
END
`,
};
