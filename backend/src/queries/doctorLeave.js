// SQL moved from the stored procedure sp_doctor_leave (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/doctorLeave'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'sp_doctor_leave',
  params: [
    { name: 'operation', type: 'VARCHAR(30)', default: null },
    { name: 'leave_id', type: 'INT', default: 'NULL' },
    { name: 'doctor_id', type: 'INT', default: 'NULL' },
    { name: 'from_date', type: 'DATE', default: 'NULL' },
    { name: 'to_date', type: 'DATE', default: 'NULL' },
    { name: 'reason', type: 'NVARCHAR(200)', default: 'NULL' },
    { name: 'clinic_id', type: 'VARCHAR(20)', default: 'NULL' },
  ],
  ops: {
    COUNT_AFFECTED: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'COUNT_AFFECTED'
    BEGIN
        SELECT COUNT(*) AS cnt
        FROM appointments a
        JOIN doctor_time_slots  dts ON dts.slot_id        = a.slot_id
        JOIN doctor_availability da  ON da.availability_id = dts.availability_id
        WHERE da.doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR da.clinic_id = @clinic_id)
          AND a.appointment_date BETWEEN @from_date AND @to_date
          AND a.appointment_date >= CAST(GETDATE() AS DATE)
          AND LOWER(a.status) IN ('booked', 'in_progress');
        RETURN;
    END

END
`,

    ADD_LEAVE: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'ADD_LEAVE'
    BEGIN
        IF @from_date IS NULL OR @to_date IS NULL OR @from_date > @to_date
        BEGIN
            SELECT CAST(NULL AS INT) AS leave_id, 'INVALID_RANGE' AS error;
            RETURN;
        END
        IF @from_date < CAST(GETDATE() AS DATE)
        BEGIN
            SELECT CAST(NULL AS INT) AS leave_id, 'PAST_DATE' AS error;
            RETURN;
        END

        INSERT INTO dbo.doctor_leave (doctor_id, clinic_id, from_date, to_date, reason)
        VALUES (@doctor_id, @clinic_id, @from_date, @to_date, @reason);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS leave_id,
               CAST(NULL AS VARCHAR(20))     AS error;
        RETURN;
    END

END
`,

    APPLY_LEAVE_CANCEL: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'APPLY_LEAVE_CANCEL'
    BEGIN
        DECLARE @affected TABLE (appointment_id INT, patient_id INT);

        INSERT INTO @affected (appointment_id, patient_id)
        SELECT a.appointment_id, a.patient_id
        FROM appointments a
        JOIN doctor_time_slots  dts ON dts.slot_id        = a.slot_id
        JOIN doctor_availability da  ON da.availability_id = dts.availability_id
        WHERE da.doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR da.clinic_id = @clinic_id)
          AND a.appointment_date BETWEEN @from_date AND @to_date
          AND a.appointment_date >= CAST(GETDATE() AS DATE)
          AND LOWER(a.status) IN ('booked', 'in_progress');

        UPDATE appointments
        SET status = 'CancleD'
        WHERE appointment_id IN (SELECT appointment_id FROM @affected);

        SELECT p.token AS fcm_token
        FROM @affected af
        JOIN patients p ON p.patient_id = af.patient_id
        WHERE p.token IS NOT NULL
          AND LTRIM(RTRIM(p.token)) <> '';
        RETURN;
    END

END
`,

    LIST_LEAVE: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'LIST_LEAVE'
    BEGIN
        SELECT leave_id,
               doctor_id,
               clinic_id,
               CONVERT(VARCHAR(10), from_date, 23) AS from_date,
               CONVERT(VARCHAR(10), to_date,   23) AS to_date,
               reason
        FROM dbo.doctor_leave
        WHERE doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR clinic_id = @clinic_id)
          AND is_active = 1
          AND to_date  >= CAST(GETDATE() AS DATE)
        ORDER BY from_date;
        RETURN;
    END

END
`,

    CANCEL_LEAVE: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'CANCEL_LEAVE'
    BEGIN
        UPDATE dbo.doctor_leave
        SET is_active = 0
        WHERE leave_id  = @leave_id
          AND doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

        SELECT @leave_id AS leave_id;
        RETURN;
    END

END
`,

    GET_LEAVE_DATES: `
BEGIN
    SET NOCOUNT ON;

   IF @operation = 'GET_LEAVE_DATES'
BEGIN
    SELECT CONVERT(VARCHAR(10), from_date, 23) AS from_date,
           CONVERT(VARCHAR(10), to_date,   23) AS to_date
    FROM dbo.doctor_leave
    WHERE doctor_id = @doctor_id
      AND (clinic_id IS NULL OR clinic_id = @clinic_id)  -- ← हे बदल
      AND is_active = 1
      AND to_date  >= CAST(GETDATE() AS DATE)
    ORDER BY from_date;
    RETURN;
END

END
`,

    IS_BLOCKED: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'IS_BLOCKED'
    BEGIN
        SELECT CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.doctor_leave
            WHERE doctor_id = @doctor_id
              AND (@clinic_id IS NULL OR clinic_id = @clinic_id)
              AND is_active  = 1
              AND @from_date BETWEEN from_date AND to_date
        ) THEN 1 ELSE 0 END AS blocked;
        RETURN;
    END
END
`,
  },
  // any other @operation value (the procedure ran none of its branches)
  other: `
BEGIN
    SET NOCOUNT ON;

END
`,
};
