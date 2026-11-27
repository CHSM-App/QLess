// SQL moved from the stored procedure sp_notification (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/notifications'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'sp_notification',
  params: [
    { name: 'operation', type: 'VARCHAR(40)', default: null },
    { name: 'notification_id', type: 'INT', default: 'NULL' },
    { name: 'patient_id', type: 'INT', default: 'NULL' },
    { name: 'title', type: 'NVARCHAR(200)', default: 'NULL' },
    { name: 'body', type: 'NVARCHAR(1000)', default: 'NULL' },
    { name: 'type', type: 'VARCHAR(40)', default: 'NULL' },
    { name: 'ref_id', type: 'VARCHAR(40)', default: 'NULL' },
    { name: 'slot_id', type: 'INT', default: 'NULL' },
    { name: 'doctor_id', type: 'INT', default: 'NULL' },
    { name: 'queue_id', type: 'INT', default: 'NULL' },
    { name: 'from_date', type: 'DATE', default: 'NULL' },
    { name: 'to_date', type: 'DATE', default: 'NULL' },
  ],
  ops: {
    // One statement, so two queue moves landing together cannot both insert
    // (the old check-then-insert raced). inserted = 0 → already sent.
    INSERT_ONCE: `
SET NOCOUNT ON;
INSERT INTO notifications (patient_id, title, body, type, ref_id)
SELECT @patient_id, @title, @body, @type, @ref_id
WHERE NOT EXISTS (
    SELECT 1 FROM notifications WITH (UPDLOCK, HOLDLOCK)
    WHERE patient_id = @patient_id AND type = @type AND ref_id = @ref_id
);
SELECT @@ROWCOUNT AS inserted;
`,

    INSERT: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'INSERT'
    BEGIN
        IF @patient_id IS NULL OR @title IS NULL OR @body IS NULL OR @type IS NULL
        BEGIN
            SELECT 0 AS success, 'patient_id, title, body and type are required' AS message;
            RETURN;
        END

        INSERT INTO notifications (patient_id, title, body, type, ref_id)
        VALUES (@patient_id, @title, @body, @type, @ref_id);

        SELECT 1 AS success,
               SCOPE_IDENTITY() AS notification_id,
               'Notification stored' AS message;
        RETURN;
    END

    SELECT 0 AS success, 'Unknown operation' AS message;
END
`,

    LIST: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'LIST'
    BEGIN
        SELECT  notification_id, patient_id, title, body, type, ref_id, is_read, created_at
        FROM    notifications
        WHERE   patient_id = @patient_id
        ORDER BY created_at DESC;
        RETURN;
    END

    SELECT 0 AS success, 'Unknown operation' AS message;
END
`,

    MARK_READ: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'MARK_READ'
    BEGIN
        UPDATE notifications
        SET    is_read = 1
        WHERE  notification_id = @notification_id AND patient_id = @patient_id;
        SELECT 1 AS success, 'Marked as read' AS message;
        RETURN;
    END

    SELECT 0 AS success, 'Unknown operation' AS message;
END
`,

    MARK_ALL_READ: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'MARK_ALL_READ'
    BEGIN
        UPDATE notifications
        SET    is_read = 1
        WHERE  patient_id = @patient_id AND is_read = 0;
        SELECT 1 AS success, 'All marked as read' AS message;
        RETURN;
    END

    SELECT 0 AS success, 'Unknown operation' AS message;
END
`,

    APPT_CONTEXT_SLOT: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'APPT_CONTEXT_SLOT'
    BEGIN
        SELECT a.appointment_id,
               a.appointment_date,
               a.start_time,
               CASE WHEN a.user_type = 1 THEN p.patient_id ELSE p2.patient_id END AS owner_id,
               CASE WHEN a.user_type = 1 THEN p.token      ELSE p2.token      END AS owner_token,
               d.name AS doctor_name
        FROM appointments a
        LEFT JOIN patients p        ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2       ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d    ON d.doctor_id  = a.doctor_id
        WHERE a.slot_id = @slot_id
          AND a.appointment_date >= CAST(GETDATE() AS DATE)
          AND a.status IN ('booked', 'in_progress');
        RETURN;
    END

    SELECT 0 AS success, 'Unknown operation' AS message;
END
`,

    APPT_CONTEXT_DOCTOR_RANGE: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'APPT_CONTEXT_DOCTOR_RANGE'
    BEGIN
        SELECT a.appointment_id,
               a.appointment_date,
               a.start_time,
               CASE WHEN a.user_type = 1 THEN p.patient_id ELSE p2.patient_id END AS owner_id,
               CASE WHEN a.user_type = 1 THEN p.token      ELSE p2.token      END AS owner_token,
               d.name AS doctor_name
        FROM appointments a
        LEFT JOIN patients p        ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2       ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d    ON d.doctor_id  = a.doctor_id
        WHERE a.doctor_id = @doctor_id
          AND a.appointment_date BETWEEN @from_date AND @to_date
          AND a.status IN ('booked', 'in_progress');
        RETURN;
    END

    SELECT 0 AS success, 'Unknown operation' AS message;
END
`,

    APPT_CONTEXT_QUEUE: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'APPT_CONTEXT_QUEUE'
    BEGIN
        DECLARE @qstop_time TIME;
        SELECT  @qstop_time = ts.start_time
        FROM    doctor_queue dq
        INNER JOIN doctor_time_slots ts ON dq.slot_id = ts.slot_id
        WHERE   dq.queue_id = @queue_id;

        SELECT a.appointment_id,
               a.appointment_date,
               a.start_time,
               CASE WHEN a.user_type = 1 THEN p.patient_id ELSE p2.patient_id END AS owner_id,
               CASE WHEN a.user_type = 1 THEN p.token      ELSE p2.token      END AS owner_token,
               d.name AS doctor_name
        FROM appointments a
        LEFT JOIN patients p        ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2       ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d    ON d.doctor_id  = a.doctor_id
        WHERE a.doctor_id = @doctor_id
          AND a.appointment_date = CAST(GETDATE() AS DATE)
          AND a.status IN ('booked', 'skipped')
          AND (
                a.queue_id = @queue_id
                OR (a.booking_type = 2 AND a.start_time < @qstop_time)
              );
        RETURN;
    END

    SELECT 0 AS success, 'Unknown operation' AS message;
END
`,
  },
  // any other @operation value (the procedure ran none of its branches)
  other: `
BEGIN
    SET NOCOUNT ON;

    SELECT 0 AS success, 'Unknown operation' AS message;
END
`,
};
