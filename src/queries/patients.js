// SQL moved from the stored procedure sp_patients (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/patients'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'sp_patients',
  params: [
    { name: 'operation', type: 'NVARCHAR(50)', default: null },
    { name: 'patient_id', type: 'INT', default: 'NULL' },
    { name: 'mobile_no', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'name', type: 'NVARCHAR(100)', default: 'NULL' },
    { name: 'Address', type: 'NVARCHAR(100)', default: 'NULL' },
    { name: 'email', type: 'NVARCHAR(100)', default: 'NULL' },
    { name: 'gender_id', type: 'INT', default: 'NULL' },
    { name: 'DOB', type: 'SMALLDATETIME', default: 'NULL' },
    { name: 'blood_group_id', type: 'INT', default: 'NULL' },
    { name: 'height', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'weight', type: 'DECIMAL(6,2)', default: 'NULL' },
    { name: 'doctor_id', type: 'int', default: 'Null' },
    { name: 'img_url', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'clinic_id', type: 'NVARCHAR(20)', default: 'NULL' },
  ],
  ops: {
    Insert: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'Insert'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
			--------------------------------------------------
        -- CHECK MOBILE ALREADY EXISTS
        --------------------------------------------------
        IF EXISTS (
            SELECT 1
            FROM dbo.Patients
            WHERE mobile_no = @mobile_no
            AND active_status = 1
        )
        BEGIN
            SELECT
                0 AS success,
                'Mobile number already exists' AS message;

            ROLLBACK TRANSACTION;
            RETURN;
        END

            INSERT INTO dbo.Patients
            (
                name,
                mobile_no,
                email,
                Address,
                gender_id,
                DOB,
                blood_group_id,
                weight,
                role_id,
                active_status
            )
            VALUES
            (   @name,
                @mobile_no,
                @email,
                @Address,
                @gender_id,
                @DOB,
                @blood_group_id,
                @weight,
                2, -- patient role
                1  -- active
            );

            SET @patient_id = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            SELECT @patient_id AS patient_id;

        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;

            SELECT ERROR_MESSAGE() AS ErrorMessage,
                   ERROR_LINE() AS ErrorLine;
        END CATCH

        RETURN;
    END

END
`,

    Update: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'Update'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            UPDATE dbo.Patients
            SET name = @name,
                mobile_no = @mobile_no,
                email = @email,
                Address = @Address,
                gender_id = @gender_id,
                DOB = @DOB,
                blood_group_id = @blood_group_id,
                weight = @weight
            WHERE patient_id = @patient_id;

            COMMIT TRANSACTION;

            SELECT @patient_id AS patient_id;

        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;

            SELECT ERROR_MESSAGE() AS ErrorMessage,
                   ERROR_LINE() AS ErrorLine;
        END CATCH

        RETURN;
    END

END
`,

    check_phone_patient: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'check_phone_patient'
    BEGIN
        SELECT *
        FROM dbo.patient_login_vw
        WHERE mobile_no = @mobile_no;
    END

END
`,

    getDoctors: `
BEGIN
    SET NOCOUNT ON;

IF @operation = 'getDoctors'
BEGIN
    SELECT
        d.*,

        --------------------------------------------------
        -- CURRENT QUEUE LENGTH (appointments based)
        --------------------------------------------------
        (
            SELECT COUNT(*)
            FROM appointments a
            WHERE a.doctor_id = d.doctor_id
                  AND a.booking_type = 1
                  AND a.status = 'booked'
                  AND a.appointment_date = CAST(GETDATE() AS DATE)
        ) AS queue_length,

        qb.is_queue_available,
        qb.is_booking_started,
        qb.current_queue_length,
        qb.max_queue_length,
        qb.is_queue_full,
        qb.booking_start_time,

        --------------------------------------------------
        -- SLOT AVAILABILITY
        --------------------------------------------------
        sa.is_slot_available,

        --------------------------------------------------
        -- RECENTLY VISITED
        --------------------------------------------------
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM appointments a2
                WHERE a2.doctor_id = d.doctor_id
                      AND a2.patient_id = @patient_id
                      AND a2.status = 'completed'
                      AND a2.appointment_date >= DATEADD(MONTH, -1, CAST(GETDATE() AS DATE))
            )
            THEN 1 ELSE 0
        END AS is_recently_visited,
	        --------------------------------------------------
        -- RATING + REVIEW COUNT (clinic-wise)
        --------------------------------------------------
        (
            SELECT AVG(CAST(rv.rating AS FLOAT))
            FROM reviews rv
            WHERE rv.doctor_id = d.doctor_id
              AND (rv.clinic_id = d.clinic_id OR rv.clinic_id IS NULL)
        ) AS rating,
        (
            SELECT COUNT(*)
            FROM reviews rv
            WHERE rv.doctor_id = d.doctor_id
              AND (rv.clinic_id = d.clinic_id OR rv.clinic_id IS NULL)
        ) AS review_count

    FROM doctor_login_vw d

    --------------------------------------------------
    -- ACTIVE DOCTORS (pending verification included; blocked ones hidden)
    --------------------------------------------------
    INNER JOIN doctor_login dl_main
        ON dl_main.doctor_id = d.doctor_id
        AND dl_main.active_status = 0

    --------------------------------------------------
    -- QUEUE LOGIC (WITH END TIME CHECK)
    --------------------------------------------------
    OUTER APPLY
    (
        SELECT TOP 1

            --------------------------------------------------
            -- QUEUE AVAILABLE (WITH START + END WINDOW)
            --------------------------------------------------
            CASE
                WHEN GETDATE() BETWEEN
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time),
                        0,0
                    )
                    AND
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.end_time),
                        DATEPART(MINUTE, ts.end_time),
                        0,0
                    )
                THEN 1
                ELSE 0
            END AS is_queue_available,

            --------------------------------------------------
            -- BOOKING START TIME
            --------------------------------------------------
            FORMAT(
                DATEADD(MINUTE,
                    -ISNULL(dl.q_start_before,0),
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time),
                        0,0
                    )
                ),
                'hh:mm tt'
            ) AS booking_start_time,

            --------------------------------------------------
            -- BOOKING STARTED
            --------------------------------------------------
            CASE
                WHEN GETDATE() >= DATEADD(MINUTE,
                    -ISNULL(dl.q_start_before,0),
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()),
                        MONTH(GETDATE()),
                        DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time),
                        0,0
                    )
                )
                THEN 1 ELSE 0
            END AS is_booking_started,

            --------------------------------------------------
            -- PENDING QUEUE (excludes completed/cancelled/skipped)
            --------------------------------------------------
            --(
            --    SELECT COUNT(*)
            --    FROM appointments a3
            --    JOIN doctor_time_slots ts3b
            --        ON ts3b.slot_id = a3.slot_id
            --    JOIN doctor_availability da3b
            --        ON da3b.availability_id = ts3b.availability_id
            --    WHERE a3.doctor_id = d.doctor_id
            --          AND a3.booking_type = 1
            --          AND a3.appointment_date = CAST(GETDATE() AS DATE)
            --          AND a3.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
            --          AND (da3b.clinic_id = d.clinic_id OR da3b.clinic_id IS NULL)
            --) AS current_queue_length,

--			(
--    SELECT COUNT(*)
--    FROM appointments a3
--    JOIN doctor_time_slots ts3b
--        ON ts3b.slot_id = a3.slot_id
--    JOIN doctor_availability da3b
--        ON da3b.availability_id = ts3b.availability_id
--    LEFT JOIN doctor_queue dq3b
--        ON dq3b.queue_id = a3.queue_id
--    WHERE a3.doctor_id = d.doctor_id
--          AND a3.booking_type = 1
--          AND a3.appointment_date = CAST(GETDATE() AS DATE)
--          AND a3.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
--          AND (da3b.clinic_id = d.clinic_id OR da3b.clinic_id IS NULL)
--          AND (dq3b.queue_status IS NULL OR dq3b.queue_status <> 3)
--) AS current_queue_length,

            --------------------------------------------------
            -- PENDING QUEUE (excludes completed/cancelled/skipped,
            -- and excludes queues the doctor has stopped or closed booking on)
            --------------------------------------------------
            (
                SELECT COUNT(*)
                FROM appointments a3
                JOIN doctor_time_slots ts3b
                    ON ts3b.slot_id = a3.slot_id
                JOIN doctor_availability da3b
                    ON da3b.availability_id = ts3b.availability_id
                LEFT JOIN doctor_queue dq3b
                    ON dq3b.queue_id = a3.queue_id
                WHERE a3.doctor_id = d.doctor_id
                      AND a3.booking_type = 1
                      AND a3.appointment_date = CAST(GETDATE() AS DATE)
                      AND a3.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
                      AND (da3b.clinic_id = d.clinic_id OR da3b.clinic_id IS NULL)
                      AND (dq3b.queue_status IS NULL OR dq3b.queue_status <> 3)
                      AND ISNULL(dq3b.booking_closed, 0) = 0
            ) AS current_queue_length,

            --------------------------------------------------
            -- MAX QUEUE
            --------------------------------------------------
            (
                SELECT SUM(ISNULL(ts2.max_queue_length,0))
                FROM doctor_availability da2
                JOIN doctor_time_slots ts2
                    ON da2.availability_id = ts2.availability_id
				WHERE da2.doctor_id = d.doctor_id
      AND (da2.clinic_id = d.clinic_id OR da2.clinic_id IS NULL)
      AND da2.is_enabled = 1
      AND ts2.is_active = 1
      AND ts2.is_deleted = 0
      AND da2.day_of_week = DATENAME(WEEKDAY, GETDATE())
      AND ts2.booking_mode IN (1,3)
            ) AS max_queue_length,

	 CASE
    WHEN
    (
        SELECT COUNT(*)
        FROM doctor_time_slots ts3
        JOIN doctor_availability da3 ON ts3.availability_id = da3.availability_id
        WHERE da3.doctor_id = d.doctor_id
          AND (da3.clinic_id = d.clinic_id OR da3.clinic_id IS NULL)
          AND da3.is_enabled = 1
          AND ts3.is_active = 1
          AND ts3.is_deleted = 0
          AND da3.day_of_week = DATENAME(WEEKDAY, GETDATE())
          AND ts3.booking_mode IN (1,3)
    ) > 0
    AND
    (
        SELECT COUNT(*)
        FROM doctor_time_slots ts3
        JOIN doctor_availability da3 ON ts3.availability_id = da3.availability_id
        LEFT JOIN doctor_queue dq3
            ON dq3.doctor_id = d.doctor_id
            AND dq3.queue_date = CAST(GETDATE() AS DATE)
            AND dq3.slot_id = ts3.slot_id
        WHERE da3.doctor_id = d.doctor_id
          AND (da3.clinic_id = d.clinic_id OR da3.clinic_id IS NULL)
          AND da3.is_enabled = 1
          AND ts3.is_active = 1
          AND ts3.is_deleted = 0
          AND da3.day_of_week = DATENAME(WEEKDAY, GETDATE())
          AND ts3.booking_mode IN (1,3)
				  AND (ts3.max_queue_length IS NULL OR ISNULL(dq3.total_queue,0) < ts3.max_queue_length)

    ) = 0
    THEN 1 ELSE 0
END AS is_queue_full

        FROM doctor_availability da
        JOIN doctor_time_slots ts
            ON da.availability_id = ts.availability_id

        LEFT JOIN doctor_login dl
            ON dl.doctor_id = d.doctor_id

		WHERE da.doctor_id = d.doctor_id
  AND (da.clinic_id = d.clinic_id OR da.clinic_id IS NULL)
  AND da.is_enabled = 1
  AND ts.is_active = 1
  AND ts.is_deleted = 0
  AND da.day_of_week = DATENAME(WEEKDAY, GETDATE())
  AND ts.booking_mode IN (1,3)

        ORDER BY
            CASE WHEN GETDATE() BETWEEN
                DATETIMEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),DAY(GETDATE()),
                    DATEPART(HOUR, ts.start_time),DATEPART(MINUTE, ts.start_time),0,0)
                AND
                DATETIMEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),DAY(GETDATE()),
                    DATEPART(HOUR, ts.end_time),DATEPART(MINUTE, ts.end_time),0,0)
            THEN 0 ELSE 1 END,
            ts.start_time
    ) qb

    --------------------------------------------------
    -- SLOT AVAILABILITY (ANY DAY)
    --------------------------------------------------
    OUTER APPLY
    (
        SELECT TOP 1
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM doctor_availability da2
                    JOIN doctor_time_slots ts2
                        ON da2.availability_id = ts2.availability_id
                    WHERE da2.doctor_id = d.doctor_id
                          AND da2.is_enabled = 1
                          AND ts2.booking_mode IN (2,3)
                )
                THEN 1 ELSE 0
            END AS is_slot_available
    ) sa
	  WHERE d.active_status = 0;
END

END
`,

    doctor_availability: `
BEGIN
    SET NOCOUNT ON;

IF @operation = 'doctor_availability'
BEGIN
    SELECT *
    FROM doctor_availability_vw
    WHERE doctor_id = @doctor_id
      AND clinic_id = @clinic_id ;
END

END
`,

    patient_mobile_exist: `
BEGIN
    SET NOCOUNT ON;

IF @operation = 'patient_mobile_exist'

BEGIN
    SELECT
        patient_id,
        mobile_no
      FROM dbo.patients
      WHERE mobile_no = @mobile_no;
    RETURN;
END

END
`,

    uploadPatientImg: `
BEGIN
    SET NOCOUNT ON;

IF @operation = 'uploadPatientImg'
BEGIN
    UPDATE Patients
    SET img_url = @img_url
    WHERE patient_id = @patient_id;

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
