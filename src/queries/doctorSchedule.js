// SQL moved from the stored procedure sp_doctor_schedule (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/doctorSchedule'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'sp_doctor_schedule',
  params: [
    { name: 'operation', type: 'VARCHAR(40)', default: null },
    { name: 'doctor_id', type: 'INT', default: 'NULL' },
    { name: 'clinic_id', type: 'NVARCHAR(20)', default: 'NULL' },
    { name: 'day_of_week', type: 'VARCHAR(10)', default: 'NULL' },
    { name: 'is_enabled', type: 'BIT', default: 'NULL' },
    { name: 'availability_id', type: 'INT', default: 'NULL' },
    { name: 'slot_id', type: 'INT', default: 'NULL' },
    { name: 'start_time', type: 'TIME', default: 'NULL' },
    { name: 'end_time', type: 'TIME', default: 'NULL' },
    { name: 'booking_mode', type: 'INT', default: 'NULL' },
    { name: 'slot_duration', type: 'INT', default: 'NULL' },
    { name: 'max_queue_length', type: 'INT', default: 'NULL' },
  ],
  ops: {
    GET: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'GET'
    BEGIN
        SELECT da.availability_id, da.day_of_week, da.is_enabled,
               dts.slot_id,
               CONVERT(VARCHAR(5), dts.start_time, 108) AS start_time,
               CONVERT(VARCHAR(5), dts.end_time,   108) AS end_time,
               dts.booking_mode, dts.slot_duration, dts.max_queue_length
        FROM doctor_availability da
        LEFT JOIN doctor_time_slots dts
            ON da.availability_id = dts.availability_id AND dts.is_active = 1
        WHERE da.doctor_id = @doctor_id
          AND (da.clinic_id = @clinic_id OR (@clinic_id IS NULL AND da.clinic_id IS NULL))
        ORDER BY CASE da.day_of_week
            WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3
            WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 WHEN 'Saturday' THEN 6
            WHEN 'Sunday' THEN 7 END, dts.start_time;
    END

END
`,

    GET_DAY_SLOT_IDS: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'GET_DAY_SLOT_IDS'
    BEGIN
        SELECT dts.slot_id
        FROM doctor_time_slots dts
        JOIN doctor_availability da ON da.availability_id = dts.availability_id
        WHERE da.doctor_id   = @doctor_id
          AND da.day_of_week = @day_of_week
          AND (da.clinic_id  = @clinic_id OR (@clinic_id IS NULL AND da.clinic_id IS NULL))
          AND dts.is_active  = 1;
    END

END
`,

    COUNT_FUTURE_APPTS_FOR_SLOT: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'COUNT_FUTURE_APPTS_FOR_SLOT'
    BEGIN
        SELECT COUNT(*) AS cnt FROM appointments
        WHERE slot_id = @slot_id AND appointment_date > CAST(GETDATE() AS DATE)
          AND LOWER(status) IN ('booked','in_progress');
    END

END
`,

    UPSERT_DAY: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'UPSERT_DAY'
    BEGIN
        DECLARE @existing_avail_id INT;
        SELECT @existing_avail_id = availability_id
        FROM doctor_availability
        WHERE doctor_id  = @doctor_id
          AND day_of_week = @day_of_week
          AND (clinic_id = @clinic_id OR (@clinic_id IS NULL AND clinic_id IS NULL));

        IF @existing_avail_id IS NULL
        BEGIN
            INSERT INTO doctor_availability (doctor_id, clinic_id, day_of_week, is_enabled)
            VALUES (@doctor_id, @clinic_id, @day_of_week, @is_enabled);
            SELECT CAST(SCOPE_IDENTITY() AS INT) AS availability_id;
        END
        ELSE
        BEGIN
            UPDATE doctor_availability SET is_enabled = @is_enabled
            WHERE availability_id = @existing_avail_id;
            SELECT @existing_avail_id AS availability_id;
        END
    END

END
`,

    DELETE_SLOT: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'DELETE_SLOT'
    BEGIN
        UPDATE doctor_time_slots SET is_active=0 WHERE slot_id=@slot_id;
    END

END
`,

    UPSERT_SLOT: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'UPSERT_SLOT'
    BEGIN
        IF @slot_id IS NULL
        BEGIN
            DECLARE @dead_slot_id INT;
            SELECT @dead_slot_id = slot_id FROM doctor_time_slots
            WHERE availability_id = @availability_id AND start_time = @start_time AND is_active = 0;

            IF @dead_slot_id IS NOT NULL
            BEGIN
                UPDATE doctor_time_slots
                SET end_time=@end_time, booking_mode=@booking_mode,
                    slot_duration=@slot_duration, max_queue_length=@max_queue_length, is_active=1
                WHERE slot_id = @dead_slot_id;
                SELECT @dead_slot_id AS slot_id;
            END
            ELSE
            BEGIN
                INSERT INTO doctor_time_slots (availability_id, start_time, end_time, booking_mode, slot_duration, max_queue_length)
                VALUES (@availability_id, @start_time, @end_time, @booking_mode, @slot_duration, @max_queue_length);
                SELECT CAST(SCOPE_IDENTITY() AS INT) AS slot_id;
            END
        END
        ELSE
        BEGIN
            UPDATE doctor_time_slots
            SET start_time=@start_time, end_time=@end_time, booking_mode=@booking_mode,
                slot_duration=@slot_duration, max_queue_length=@max_queue_length, is_active=1
            WHERE slot_id = @slot_id AND availability_id = @availability_id;
            SELECT @slot_id AS slot_id;
        END
    END

END
`,

    CANCEL_FUTURE_APPTS_FOR_SLOT: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'CANCEL_FUTURE_APPTS_FOR_SLOT'
    BEGIN
        DECLARE @affected TABLE (appointment_id INT, patient_id INT);
        INSERT INTO @affected SELECT appointment_id, patient_id FROM appointments
        WHERE slot_id = @slot_id AND appointment_date > CAST(GETDATE() AS DATE)
          AND LOWER(status) IN ('booked','in_progress');

        UPDATE appointments SET status='CancleD'
        WHERE appointment_id IN (SELECT appointment_id FROM @affected);

        SELECT CASE WHEN ap.user_type=1 THEN p.token WHEN ap.user_type=2 THEN p2.token END AS fcm_token
        FROM @affected a
        JOIN appointments ap ON ap.appointment_id = a.appointment_id
        LEFT JOIN patients p ON ap.user_type=1 AND p.patient_id=ap.patient_id
        LEFT JOIN family_members fm ON ap.user_type=2 AND fm.member_id=ap.patient_id
        LEFT JOIN patients p2 ON fm.family_id=p2.patient_id
        WHERE COALESCE(CASE WHEN ap.user_type=1 THEN p.token WHEN ap.user_type=2 THEN p2.token END,'') <> '';
    END

END
`,

    RESCHEDULE_FUTURE_APPTS_FOR_SLOT: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'RESCHEDULE_FUTURE_APPTS_FOR_SLOT'
    BEGIN
        DECLARE @affectedR TABLE (appointment_id INT, patient_id INT);
        INSERT INTO @affectedR SELECT appointment_id, patient_id FROM appointments
        WHERE slot_id = @slot_id AND appointment_date > CAST(GETDATE() AS DATE)
          AND LOWER(status) IN ('booked','in_progress');

        UPDATE appointments SET status='reschedule'
        WHERE appointment_id IN (SELECT appointment_id FROM @affectedR);

        SELECT p.token FROM @affectedR a
        JOIN patients p ON p.patient_id=a.patient_id
        WHERE p.token IS NOT NULL AND LTRIM(RTRIM(p.token)) <> '';
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
