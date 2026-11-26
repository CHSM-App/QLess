// SQL moved from the stored procedure sp_appointment (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/appointments'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'sp_appointment',
  params: [
    { name: 'operation', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'doctor_id', type: 'INT', default: 'NULL' },
    { name: 'patient_id', type: 'INT', default: 'NULL' },
    { name: 'family_id', type: 'INT', default: 'NULL' },
    { name: 'appointment_id', type: 'INT', default: 'NULL' },
    { name: 'appointment_date', type: 'DATE', default: 'NULL' },
    { name: 'user_type', type: 'INT', default: 'NULL' },
    { name: 'start_time', type: 'TIME', default: 'NULL' },
    { name: 'default_avg', type: 'INT', default: '7' },
    { name: 'slot_id', type: 'int', default: '0' },
    { name: 'patient_id_local', type: 'INT', default: 'NULL' },
    { name: 'queue_id', type: 'INT', default: 'NULL' },
    { name: 'token', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'is_next', type: 'INT', default: 'NULL' },
    { name: 'symptoms', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'clinic_id', type: 'NVARCHAR(20)', default: 'NULL' },
  ],
  ops: {
    // Not in the old procedure (the leave/slot routes called it and got
    // nothing back). 'CancleD' is how the app tells "cancelled by doctor"
    // apart from a patient's own 'cancelled'; the collation is
    // case-insensitive, so both spellings match the IN list.
    MARK_APPT_DOCTOR_CANCELLED: `
SET NOCOUNT ON;
UPDATE appointments SET status = 'CancleD'
WHERE appointment_id = @appointment_id AND status IN ('cancelled', 'cancled');
`,

    BOOK: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'BOOK'
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;

                IF EXISTS
                (
                    SELECT 1
                    FROM doctor_unavailability
                    WHERE doctor_id = @doctor_id
                          AND unavailable_date = @appointment_date
                )
                    RAISERROR('Doctor Unavailable', 16, 1);

                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND patient_id = @patient_id
                          AND user_type = @user_type
                          AND appointment_date = @appointment_date
                          AND slot_id = @slot_id
                          AND status = 'booked'
                )
                    RAISERROR('Already booked', 16, 1);

                --------------------------------------------------
                -- GET SLOT / MODE
                --------------------------------------------------

                IF (@start_time IS NULL)
                BEGIN
                    SET @booking_mode = 1;
                END
                ELSE
                BEGIN
                    SET @booking_mode = 2;
                END;

                IF @booking_mode IS NULL
                    RAISERROR('No valid slot found', 16, 1);

                --------------------------------------------------
                -- SLOT BOOKING
                --------------------------------------------------
                IF @booking_mode = 2
                BEGIN
                    --------------------------------------------------
                    -- 🔥 FETCH SLOT DATA
                    --------------------------------------------------
                    SELECT @slot_start = start_time,
                           @slot_end = end_time,
                           @slot_duration = slot_duration
                    FROM doctor_time_slots
                    WHERE slot_id = @slot_id;

                    --------------------------------------------------
                    -- VALIDATIONS
                    --------------------------------------------------
                    IF @slot_duration IS NULL
                        RAISERROR('Slot duration not defined', 16, 1);

                    IF @start_time < @slot_start
                       OR @start_time >= @slot_end
                        RAISERROR('Invalid slot time range', 16, 1);

                    SET @minutes = DATEDIFF(MINUTE, @slot_start, @start_time);

                    IF @minutes % @slot_duration <> 0
                        RAISERROR('Invalid slot interval', 16, 1);

                    IF @appointment_date < CAST(GETDATE() AS DATE)
                        RAISERROR('Cannot book a past date', 16, 1);

                    -- same rule GET_MONTH_SLOTS uses to show a slot as taken
                    IF EXISTS (SELECT 1 FROM appointments WITH (UPDLOCK, HOLDLOCK)
                               WHERE doctor_id = @doctor_id AND appointment_date = @appointment_date
                                 AND start_time = @start_time AND status = 'booked')
                        RAISERROR('Slot already booked', 16, 1);

                    --------------------------------------------------
                    -- INSERT
                    --------------------------------------------------
                    INSERT INTO appointments
                    (
                        doctor_id,
                        patient_id,
                        user_type,
                        appointment_date,
                        start_time,
                        end_time,
                        booking_type,
                        slot_id,
                        queue_number,
                        queue_id,
                        symptoms,
						clinic_id
                    )
                    VALUES
                    (   @doctor_id,
                        @patient_id,
                        @user_type,
                        @appointment_date,
                        @start_time,
                        DATEADD(MINUTE, @slot_duration, @start_time), -- ✅ FIXED
                        2,
                        @slot_id,
                        NULL,
                        NULL,
                        @symptoms,
						@clinic_id
                    );
                END

                --------------------------------------------------
                -- QUEUE BOOKING
                --------------------------------------------------
                ELSE IF @booking_mode = 1
                BEGIN
                    IF @appointment_date <> CAST(GETDATE() AS DATE)
                        RAISERROR('Queue only for today', 16, 1);

                    --------------------------------------------------
                    -- GET NEXT QUEUE NUMBER
                    --------------------------------------------------
                    SELECT @next_queue = ISNULL(MAX(queue_number), 0) + 1
                    FROM appointments WITH (UPDLOCK, HOLDLOCK)
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = @appointment_date
                          AND slot_id = @slot_id;

                    --------------------------------------------------
                    -- UPSERT doctor_queue + GET queue_id
                    --------------------------------------------------
                    SELECT @temp_slot = queue_id,
                           @max_queue_length = max_queue,
                           @total_queue = total_queue
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND slot_id = @slot_id
                          AND queue_date = @appointment_date
						   AND (@clinic_id IS NULL OR clinic_id = @clinic_id OR clinic_id IS NULL);

                    if (isnull(@temp_slot, 0) > 0)
                    BEGIN
                        IF (ISNULL(@total_queue, 0) + 1 > @max_queue_length)
                            RAISERROR('Queue Full', 16, 1);

                        UPDATE doctor_queue
                        SET total_queue = ISNULL(total_queue, 0) + 1,
                            clinic_id   = COALESCE(clinic_id, @clinic_id)
                        where queue_id = @temp_slot;

                    END
                    else
                    BEGIN
                        INSERT INTO doctor_queue
                        (
                            slot_id,
                            doctor_id,
                            queue_date,
                            total_queue,
                            current_serving,
                            current_patient_id,
                            queue_status,
                            completed_count,
                            max_queue,
							   clinic_id
                        )
                        SELECT @slot_id,
                               @doctor_id,
                               @appointment_date,
                               1,
                               0,
                               @patient_id,
                               0,
                               0,
                               ts.max_queue_length,
							    @clinic_id
                        FROM doctor_time_slots ts
                        WHERE ts.slot_id = @slot_id;
                    END;

                    --------------------------------------------------
                    -- GET queue_id
                    --------------------------------------------------
                    SELECT @queue_id = queue_id
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = @appointment_date
                          AND slot_id = @slot_id
						   AND (@clinic_id IS NULL OR clinic_id = @clinic_id OR clinic_id IS NULL);

                    --------------------------------------------------
                    -- INSERT APPOINTMENT
                    --------------------------------------------------
                    INSERT INTO appointments
                    (
                        doctor_id,
                        patient_id,
                        user_type,
                        appointment_date,
                        booking_type,
                        queue_number,
                        queue_id,
                        slot_id,
                        symptoms,
						clinic_id
                    )
                    VALUES
                    (@doctor_id,
                     @patient_id,
                     @user_type,
                     @appointment_date,
                     1  ,
                     @next_queue,
                     @queue_id,
                     @slot_id,
                     @symptoms,
					 @clinic_id
                    );
                END

                COMMIT;

                SELECT 1 AS success,
                       'Booked Successfully' AS message;
            END TRY
            BEGIN CATCH
                ROLLBACK;

                SELECT 0 AS success,
                       ERROR_MESSAGE() AS message,
                       ERROR_MESSAGE() AS error;
            END CATCH
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    GET_AVAILABILITY: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'GET_AVAILABILITY'
        BEGIN
            SET @day = DATENAME(WEEKDAY, @appointment_date);

            SELECT ts.slot_id,
                   ts.start_time,
                   ts.end_time,
                   ts.booking_mode,
                   ts.slot_duration,
                   (
                       SELECT COUNT(*)
                       FROM appointments a
                       WHERE a.doctor_id = @doctor_id
                             AND a.appointment_date = @appointment_date
                             AND a.start_time = ts.start_time
                             AND a.status = 'booked'
                   ) AS booked_count
            FROM doctor_availability da
                JOIN doctor_time_slots ts
                    ON da.availability_id = ts.availability_id
            WHERE da.doctor_id = @doctor_id
                  AND da.day_of_week = @day
                  AND da.is_enabled = 1
				   AND (da.clinic_id = @clinic_id OR da.clinic_id IS NULL OR @clinic_id IS NULL); -- ← ADD;
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    CANCEL_APPOINTMENT: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'CANCEL_APPOINTMENT'
        BEGIN

            --------------------------------------------------
            -- GET QUEUE ID FROM APPOINTMENT
            --------------------------------------------------
            SELECT @queue_id = queue_id
            FROM appointments
            WHERE appointment_id = @appointment_id;

            --------------------------------------------------
            -- UPDATE APPOINTMENT STATUS
            --------------------------------------------------
            UPDATE appointments
            SET status = 'cancelled'
            WHERE appointment_id = @appointment_id;

            --------------------------------------------------
            -- REDUCE QUEUE COUNT
            --------------------------------------------------
            IF @queue_id IS NOT NULL
            BEGIN
                UPDATE doctor_queue
                SET total_queue = CASE
                                      WHEN total_queue > 0 THEN
                                          total_queue - 1
                                      ELSE
                                          0
                                  END
                WHERE queue_id = @queue_id;
            END

            SELECT 1 AS success,
                   'Cancelled Successfully' AS message;
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    GET_MONTH_SLOTS: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

		IF @operation = 'GET_MONTH_SLOTS'
BEGIN
    SET @start_date = CAST(GETDATE() AS DATE);
    --SET @end_date = EOMONTH(@start_date);
	SET @end_date = EOMONTH(DATEADD(MONTH, 1, @start_date));

    ;WITH DateCTE AS (
        SELECT @start_date AS booking_date
        UNION ALL
        SELECT DATEADD(DAY, 1, booking_date)
        FROM DateCTE
        WHERE booking_date < @end_date
    ),
    AvailableDays AS (
        SELECT d.booking_date, da.availability_id
        FROM DateCTE d
        JOIN doctor_availability da
            ON LOWER(LTRIM(RTRIM(da.day_of_week))) = LOWER(DATENAME(WEEKDAY, d.booking_date))
           AND da.doctor_id = @doctor_id
           AND da.clinic_id = @clinic_id
           AND da.is_enabled = 1
    ),
    --Slots AS (
    --    SELECT ad.booking_date, ts.start_time, ts.end_time, ts.slot_duration
    --    FROM AvailableDays ad
    --    JOIN doctor_time_slots ts ON ts.availability_id = ad.availability_id
    --    WHERE ts.booking_mode = 2
	  Slots AS (
        SELECT ad.booking_date, ts.start_time, ts.end_time, ts.slot_duration
        FROM AvailableDays ad
        JOIN doctor_time_slots ts ON ts.availability_id = ad.availability_id
        WHERE ts.booking_mode IN (2, 3)   -- ← 2 la IN (2,3) kar

    ),
    SlotCTE AS (
        SELECT booking_date, start_time, end_time, slot_duration, start_time AS slot_time
        FROM Slots
        UNION ALL
        SELECT booking_date, start_time, end_time, slot_duration,
               DATEADD(MINUTE, slot_duration, slot_time)
        FROM SlotCTE
        WHERE DATEADD(MINUTE, slot_duration, slot_time) < end_time
    )
    SELECT s.booking_date,
           s.slot_time AS start_time,
           DATEADD(MINUTE, s.slot_duration, s.slot_time) AS end_time,
           1 AS is_booked
    FROM SlotCTE s
    INNER JOIN appointments a
        ON a.doctor_id        = @doctor_id
       AND a.clinic_id        = @clinic_id
       AND a.appointment_date = s.booking_date
       AND a.start_time       = s.slot_time
       AND a.status           = 'booked'
    ORDER BY s.booking_date, s.slot_time
    OPTION (MAXRECURSION 1000);
END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    QUEUE_STATUS: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'QUEUE_STATUS'
        BEGIN
            SELECT ISNULL(total_queue, 0) AS total_queue,
                   ISNULL(current_serving, 0) AS current_serving,
                   ISNULL(total_queue, 0) - ISNULL(current_serving, 0) AS waiting_count
            FROM doctor_queue
            WHERE doctor_id = @doctor_id
                  AND queue_date = @appointment_date;
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    CANCEL_BY_DOCTOR: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'CANCEL_BY_DOCTOR'
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;

                --------------------------------------------------
                -- VALIDATE APPOINTMENT
                --------------------------------------------------
                SELECT @booking_type = booking_type
                FROM appointments
                WHERE appointment_id = @appointment_id
                      AND doctor_id = @doctor_id;

                IF @booking_type IS NULL
                    RAISERROR('Invalid appointment', 16, 1);

                --------------------------------------------------
                -- 🔥 ONLY SLOT ALLOWED
                --------------------------------------------------
                IF @booking_type <> 2
                    RAISERROR('Doctor can cancel only slot appointments', 16, 1);

                --------------------------------------------------
                -- UPDATE STATUS
                --------------------------------------------------
                UPDATE appointments
                SET status = 'CancleD'
                WHERE appointment_id = @appointment_id;

                COMMIT;

                SELECT 1 AS success,
                       'Slot appointment cancelled successfully' AS message;

            END TRY
            BEGIN CATCH
                ROLLBACK;

                SELECT 0 AS success,
                       ERROR_MESSAGE() AS message,
                       ERROR_MESSAGE() AS error;
            END CATCH
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    QUEUE_START: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'QUEUE_START'
        BEGIN
            --------------------------------------------------
            -- START / CREATE QUEUE
            --------------------------------------------------

            UPDATE doctor_queue
            SET queue_status = 1,
                started_at = GETDATE(),
                current_serving = 0
            --current_queue_no = NULL
            WHERE doctor_id = @doctor_id
                  AND queue_id = @queue_id
                  AND queue_date = CAST(GETDATE() AS DATE);

            --MERGE doctor_queue AS dq
            --USING
            --(
            --    SELECT @doctor_id AS doctor_id,
            --           CAST(GETDATE() AS DATE) AS queue_date
            --) src
            --ON dq.doctor_id = src.doctor_id
            --   AND dq.queue_date = src.queue_date
            --WHEN MATCHED THEN
            --    UPDATE SET queue_status = 1,
            --               started_at = GETDATE(),
            --               current_serving = 0,
            --               current_queue_no = NULL
            --WHEN NOT MATCHED THEN
            --    INSERT
            --    (
            --        doctor_id,
            --        queue_date,
            --        queue_status,
            --        current_serving,
            --        total_queue,
            --        current_queue_no,
            --        completed_count,
            --        started_at
            --    )
            --    VALUES
            --    (@doctor_id, CAST(GETDATE() AS DATE), 1, 0, 0, NULL, 0, GETDATE());

            --------------------------------------------------
            -- 🔥 RETURN TOKENS (CORRECT LOGIC)
            --------------------------------------------------
            SELECT a.appointment_id,
                   a.queue_number,

                   --------------------------------------------------
                   -- 🔥 TOKEN RESOLUTION
                   --------------------------------------------------
                   CASE
                       WHEN a.user_type = 1 THEN
                           p.token
                       WHEN a.user_type = 2 THEN
                           p2.token
                   END AS token
            FROM appointments a

                --------------------------------------------------
                -- DIRECT PATIENT
                --------------------------------------------------
                LEFT JOIN patients p
                    ON a.user_type = 1
                       AND p.patient_id = a.patient_id

                --------------------------------------------------
                -- FAMILY MEMBER → MAP TO PATIENT
                --------------------------------------------------
                LEFT JOIN family_members fm
                    ON a.user_type = 2
                       AND fm.member_id = a.patient_id
                LEFT JOIN patients p2
                    ON fm.family_id = p2.patient_id
            WHERE a.doctor_id = @doctor_id
                  AND queue_id = @queue_id
                  AND a.appointment_date = CAST(GETDATE() AS DATE)
                  AND a.booking_type = 1
                  AND a.status IN ( 'booked', 'in_progress' )
            ORDER BY a.queue_number;

        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    GET_TODAY_QUEUE: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'GET_TODAY_QUEUE'
        BEGIN
            BEGIN TRY

                --------------------------------------------------
                -- FETCH QUEUES WITH SESSION TIME (slot )
                --------------------------------------------------
                SELECT dq.queue_id,
                       dq.doctor_id,
                       dq.queue_date,
                       dq.slot_id,

                       --------------------------------------------------
                       -- 🔥 CORRECT SLOT TIME (DIRECT FROM SLOT_ID)
                       --------------------------------------------------
                       ts.start_time,
                       ts.end_time,
                       dq.queue_status,
                       dq.current_serving,
                       dq.current_patient_id,
                       dq.total_queue,
                       dq.completed_count,
                       dq.started_at,
                       dq.stopped_at
                FROM doctor_queue dq

                    --------------------------------------------------
                    -- 🔥 DIRECT SLOT JOIN (IMPORTANT)
                    --------------------------------------------------
                    LEFT JOIN doctor_time_slots ts
                        ON dq.slot_id = ts.slot_id
                    LEFT JOIN doctor_availability da
                        ON da.availability_id = ts.availability_id

                --------------------------------------------------
                -- FILTER
                --------------------------------------------------
                WHERE dq.doctor_id = @doctor_id
                      AND dq.queue_date = CAST(GETDATE() AS DATE)
                      AND (@clinic_id IS NULL OR dq.clinic_id = @clinic_id OR dq.clinic_id IS NULL)
                ORDER BY ts.start_time;

                --------------------------------------------------
                -- STATUS
                --------------------------------------------------
                SELECT 1 AS success,
                       'Today queue fetched' AS message;

            END TRY
            BEGIN CATCH
                SELECT 0 AS success,
                       ERROR_MESSAGE() AS message,
                       ERROR_MESSAGE() AS error;
            END CATCH
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    QUEUE_PAUSE: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'QUEUE_PAUSE'
        BEGIN
            --------------------------------------------------
            -- PAUSE QUEUE (YOUR ORIGINAL LOGIC)
            --------------------------------------------------
            UPDATE doctor_queue
            SET queue_status = 2 -- 2 = paused
            WHERE doctor_id = @doctor_id
                  AND queue_id = @queue_id
                  AND queue_date = CAST(GETDATE() AS DATE);

            --------------------------------------------------
            -- CHECK SUCCESS
            --------------------------------------------------
            IF @@ROWCOUNT = 0
            BEGIN
                SELECT 0 AS success,
                       'Queue not found or already paused' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SUCCESS RESPONSE (RESULT SET 1)
            --------------------------------------------------
            SELECT 1 AS success,
                   'Queue paused' AS message;

            --------------------------------------------------
            -- 🔥 RETURN TOKENS (RESULT SET 2)
            --------------------------------------------------
            SELECT a.appointment_id,
                   a.queue_number,
                   CASE
                       WHEN a.user_type = 1 THEN
                           p.token
                       WHEN a.user_type = 2 THEN
                           p2.token
                   END AS token
            FROM appointments a
                LEFT JOIN patients p
                    ON a.user_type = 1
                       AND p.patient_id = a.patient_id
                LEFT JOIN family_members fm
                    ON a.user_type = 2
                       AND fm.member_id = a.patient_id
                LEFT JOIN patients p2
                    ON fm.family_id = p2.patient_id
            WHERE a.doctor_id = @doctor_id
                  AND a.appointment_date = CAST(GETDATE() AS DATE)
                  AND a.booking_type = 1
                  AND queue_id = @queue_id
                  AND a.status IN ( 'booked', 'in_progress' )
            ORDER BY a.queue_number;

        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    QUEUE_PAUSE_EMERGENCY: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

IF @operation = 'QUEUE_PAUSE_EMERGENCY'
BEGIN
    BEGIN TRY

        IF @queue_id IS NULL
        BEGIN
            SELECT 0 AS success, 'queue_id required' AS message;
            RETURN;
        END

        DECLARE @q_doctor_id  INT;
        DECLARE @current_stat INT;

        SELECT @q_doctor_id  = doctor_id,
               @current_stat = queue_status
        FROM doctor_queue
        WHERE queue_id = @queue_id;

        IF @q_doctor_id IS NULL
        BEGIN
            SELECT 0 AS success, 'Invalid queue' AS message;
            RETURN;
        END

        --------------------------------------------------
        -- IDEMPOTENCY CHECK
        -- queue_status: 0=not started, 1=active, 2=paused, 3=stopped, 4=emergency
        --------------------------------------------------
        IF @current_stat = 4
        BEGIN
            SELECT 0 AS success,
                   'Queue is already in emergency pause' AS message;
            RETURN;
        END

        IF @current_stat = 3
        BEGIN
            SELECT 0 AS success,
                   'Queue is already stopped' AS message;
            RETURN;
        END

        --------------------------------------------------
        -- UPDATE STATUS → 4 (EMERGENCY PAUSED)
        --------------------------------------------------
        UPDATE doctor_queue
        SET queue_status = 4
        WHERE queue_id = @queue_id;

        --------------------------------------------------
        -- SUCCESS RESPONSE (RESULT SET 1)
        --------------------------------------------------
        SELECT 1 AS success,
               'Queue paused successfully' AS message;

        --------------------------------------------------
        -- TOKENS (RESULT SET 2)
        --------------------------------------------------
        SELECT a.appointment_id,
               a.queue_number,
               CASE
                   WHEN a.user_type = 1 THEN p.token
                   WHEN a.user_type = 2 THEN p2.token
               END AS token
        FROM appointments a
            LEFT JOIN patients p
                ON a.user_type = 1
                   AND p.patient_id = a.patient_id
            LEFT JOIN family_members fm
                ON a.user_type = 2
                   AND fm.member_id = a.patient_id
            LEFT JOIN patients p2
                ON fm.family_id = p2.patient_id
        WHERE a.doctor_id = @q_doctor_id
              AND a.appointment_date = CAST(GETDATE() AS DATE)
              AND a.booking_type = 1
              AND a.queue_id = @queue_id
              AND a.status IN ('booked', 'in_progress')
        ORDER BY a.queue_number;

    END TRY
    BEGIN CATCH
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message,
               ERROR_MESSAGE() AS error;
    END CATCH
END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    QUEUE_STOP: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'QUEUE_STOP'
        BEGIN
            DECLARE @qstop_start_time TIME;

            -- Get start_time of the queue being stopped (from its slot)
            SELECT TOP 1 @qstop_start_time = ts.start_time
            FROM doctor_queue dq
                INNER JOIN doctor_time_slots ts ON dq.slot_id = ts.slot_id
            WHERE dq.doctor_id  = @doctor_id
              AND dq.queue_id   = @queue_id
              AND dq.queue_date = CAST(GETDATE() AS DATE);

            -- Close this queue only
            UPDATE doctor_queue
            SET queue_status = 3,
                stopped_at   = GETDATE()
            WHERE doctor_id  = @doctor_id
              AND queue_id   = @queue_id
              AND queue_date = CAST(GETDATE() AS DATE);

            -- THIS queue's pending (booked + skipped) → cancelled
            UPDATE appointments
            SET status = 'CancleD'
            WHERE queue_id = @queue_id
              AND status IN ('skipped', 'booked');

            -- Earlier-time slot bookings (booking_type=2) before this queue's time → cancelled
            UPDATE appointments
            SET status = 'CancleD'
            WHERE doctor_id        = @doctor_id
              AND booking_type     = 2
              AND appointment_date = CAST(GETDATE() AS DATE)
              AND status IN ('booked', 'skipped')
              AND start_time       < @qstop_start_time;

            SELECT 1 success,
                   'Queue stopped' message;
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    QUEUE_PROXIMITY_LIST: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

IF @operation = 'QUEUE_PROXIMITY_LIST'
BEGIN
    DECLARE @prox_hour INT = DATEPART(HOUR, GETDATE());
    DECLARE @prox_avg  INT;

    SELECT @prox_avg = COALESCE(
        CASE
            WHEN @prox_hour < 12 THEN morning_avg
            WHEN @prox_hour < 17 THEN afternoon_avg
            ELSE evening_avg
        END,
        avg_consultation_time,
        @default_avg
    )
    FROM doctor_timing
    WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

    IF @prox_avg IS NULL SET @prox_avg = @default_avg;
    IF @prox_avg < 3     SET @prox_avg = 3;
    IF @prox_avg > 30    SET @prox_avg = 30;

    SELECT
        a.appointment_id,
        CASE
            WHEN a.user_type = 1 THEN a.patient_id
            WHEN a.user_type = 2 THEN fm.family_id
        END AS owner_id,
        CASE
            WHEN a.user_type = 1 THEN p.token
            WHEN a.user_type = 2 THEN p2.token
        END AS owner_token,
        ISNULL(d.name, 'your doctor') AS doctor_name,
        (a.queue_number - dq.current_serving - 1) * @prox_avg AS est_minutes_to_turn
    FROM appointments a
        INNER JOIN doctor_queue dq
            ON dq.queue_id = a.queue_id
        LEFT JOIN patients p
            ON a.user_type = 1 AND p.patient_id = a.patient_id
        LEFT JOIN family_members fm
            ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients p2
            ON fm.family_id = p2.patient_id
        LEFT JOIN doctor_login d
            ON d.doctor_id = a.doctor_id
    WHERE a.doctor_id        = @doctor_id
      AND a.appointment_date = CAST(GETDATE() AS DATE)
      AND a.booking_type     = 1
      AND a.status           = 'booked'
      AND dq.queue_status    = 1
      AND (a.queue_number - dq.current_serving) > 1
    ORDER BY est_minutes_to_turn;
END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    NEXT_SESSION: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'NEXT_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET CURRENT APPOINTMENT DETAILS
            --------------------------------------------------
            SELECT @booking_type = booking_type,
                   @slot_id = slot_id,
                   @queue_id = queue_id,                 -- ✅ ADD
                   @current_queue = queue_number
            FROM appointments
            WHERE appointment_id = @appointment_id
                  AND doctor_id = @doctor_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED (✅ queue_id scoped)
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE queue_id = @queue_id        -- ✅ specific session
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- COMPLETE CURRENT
                --------------------------------------------------
                --UPDATE appointments
                --SET end_time = GETDATE(),
                --    status = 'completed'
                --WHERE appointment_id = @appointment_id
                --      AND booking_type = 1
                --      AND status = 'in_progress';

                --IF @@ROWCOUNT = 0
                --BEGIN
                --    SELECT 0 AS success,
                --           'Invalid active appointment' AS message;
                --    RETURN;
                --END

				                --------------------------------------------------
                -- COMPLETE CURRENT (in_progress किंवा booked)
                --------------------------------------------------
                UPDATE appointments
                SET end_time = GETDATE(),
                    status = 'completed'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 1
                      AND status IN ('in_progress', 'booked');

                --------------------------------------------------
                -- UPDATE COMPLETED COUNT (✅ this queue only)
                --------------------------------------------------
                UPDATE doctor_queue
                SET completed_count = ISNULL(completed_count, 0) + 1
                WHERE queue_id = @queue_id;           -- ✅

                --------------------------------------------------
                -- FIND NEXT IN SAME SESSION (✅ queue_id scoped)
                --------------------------------------------------
                SELECT TOP 1
                    @next_queue = queue_number,
                    @qn_next_patient_id = patient_id,
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE queue_id = @queue_id            -- ✅
                      AND booking_type = 1
                      AND status = 'booked'
                      AND queue_number > @current_queue
                ORDER BY queue_number;

                --------------------------------------------------
                -- NO NEXT IN THIS SESSION
                --------------------------------------------------
                IF @next_queue IS NULL
                BEGIN
                    --------------------------------------------------
                    -- CHECK SKIPPED IN SAME SESSION (✅ queue_id scoped)
                    --------------------------------------------------
                    IF EXISTS
                    (
                        SELECT 1
                        FROM appointments
                        WHERE queue_id = @queue_id    -- ✅
                              AND booking_type = 1
                              AND status = 'skipped'
                    )
                    BEGIN
                        UPDATE doctor_queue
                        SET current_patient_id = NULL
                        WHERE queue_id = @queue_id;   -- ✅

                        SELECT 1 AS success,
                               'Booked done. Skipped pending.' AS message;
                        RETURN;
                    END

                    --------------------------------------------------
                    -- CLOSE ONLY THIS SESSION (✅ queue_id scoped)
                    --------------------------------------------------
                    UPDATE doctor_queue
                    SET current_patient_id = NULL
                    WHERE queue_id = @queue_id;       -- ✅

                    SELECT 1 AS success,
                           'No Patient Left' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT IN SAME SESSION
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @next_appointment_id;

                --------------------------------------------------
                -- UPDATE POINTER (✅ queue_id scoped)
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving = @next_queue,
                    current_patient_id = @qn_next_patient_id
                WHERE queue_id = @queue_id;           -- ✅

                --------------------------------------------------
                -- CONSULTATION TIME TRACKING (unchanged)
                --------------------------------------------------
                SELECT @consult_time = DATEDIFF(MINUTE, start_time, end_time)
                FROM appointments
                WHERE appointment_id = @appointment_id;
				IF @consult_time IS NOT NULL
BEGIN
    SET @hour = DATEPART(HOUR, GETDATE());
    DECLARE @effective_clinic VARCHAR(50) = ISNULL(@clinic_id, 'DEFAULT');

    IF NOT EXISTS (
        SELECT 1 FROM doctor_timing
        WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic
    )
    BEGIN
        INSERT INTO doctor_timing
            (doctor_id, clinic_id, avg_consultation_time,
             morning_avg, afternoon_avg, evening_avg,
             total_completed, last_updated)
        VALUES
            (@doctor_id, @effective_clinic, @consult_time,
             NULL, NULL, NULL, 1, GETDATE());
    END
    ELSE
    BEGIN
        UPDATE doctor_timing
        SET avg_consultation_time = (avg_consultation_time * total_completed + @consult_time)
                                    / (total_completed + 1),
            total_completed = total_completed + 1,
            last_updated = GETDATE()
        WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;

        IF @hour < 12
            UPDATE doctor_timing
            SET morning_avg = ISNULL((morning_avg + @consult_time) / 2, @consult_time)
            WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;
        ELSE IF @hour < 17
            UPDATE doctor_timing
            SET afternoon_avg = ISNULL((afternoon_avg + @consult_time) / 2, @consult_time)
            WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;
        ELSE
            UPDATE doctor_timing
            SET evening_avg = ISNULL((evening_avg + @consult_time) / 2, @consult_time)
            WHERE doctor_id = @doctor_id AND clinic_id = @effective_clinic;
    END
END

                SELECT 1 AS success,
                       'Next queue patient started' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- COMPLETE CURRENT SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'completed'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 2
                      AND status = 'in_progress';

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 0 AS success,
                           'Invalid active slot' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- FIND NEXT SLOT IN SAME SESSION (✅ DATE + DOCTOR filter)
                --------------------------------------------------
                SELECT TOP 1
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE slot_id = @slot_id
                      AND doctor_id = @doctor_id                      -- ✅
                      AND appointment_date = CAST(GETDATE() AS DATE)  -- ✅ TODAY only
                      AND booking_type = 2
                      AND status = 'booked'
                ORDER BY start_time;

                --------------------------------------------------
                -- NO NEXT SLOT
                --------------------------------------------------
                IF @next_appointment_id IS NULL
                BEGIN
                    SELECT 1 AS success,
                           'No Patient Left' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress',
                    start_time = GETDATE()
                WHERE appointment_id = @next_appointment_id;

                SELECT 1 AS success,
                       'Next slot started' AS message;
                RETURN;
            END
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    SKIP_SESSION: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'SKIP_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET APPOINTMENT DETAILS
            --------------------------------------------------
            SELECT @booking_type = booking_type,
                   @slot_id = slot_id,
                   @current_queue = queue_number,
                   @user_type = user_type,
                   @patient_id_local = patient_id
            FROM appointments
            WHERE appointment_id = @appointment_id
                  AND doctor_id = @doctor_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message,
                       NULL AS token;
                RETURN;
            END

            --------------------------------------------------
            -- GET TOKEN
            --------------------------------------------------
            IF @user_type = 1
            BEGIN
                SELECT @token = token
                FROM patients
                WHERE patient_id = @patient_id_local;
            END
            ELSE IF @user_type = 2
            BEGIN
                SELECT @token = p.token
                FROM family_members fm
                    JOIN patients p
                        ON fm.family_id = p.patient_id
                WHERE fm.member_id = @patient_id_local;
            END

            --------------------------------------------------
            -- QUEUE FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE slot_id = @slot_id
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- SKIP CURRENT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'skipped'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 1
                      AND status IN ( 'booked', 'in_progress' );

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 0 AS success,
                           'Invalid active queue appointment' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- IF NOT MOVE NEXT
                --------------------------------------------------
                IF @is_next = 0
                BEGIN
                    UPDATE doctor_queue
                    SET current_patient_id = NULL,
                        current_serving = NULL
                    WHERE slot_id = @slot_id;

                    SELECT 1 AS success,
                           'Patient skipped.' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- FIND NEXT IN SAME SESSION
                --------------------------------------------------
                SELECT TOP 1
                    @next_queue = queue_number,
                    @next_patient_id = patient_id,
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE slot_id = @slot_id
                      AND booking_type = 1
                      AND status = 'booked'
                      AND queue_number > @current_queue
                ORDER BY queue_number;

                --------------------------------------------------
                -- NO NEXT
                --------------------------------------------------
                IF @next_queue IS NULL
                BEGIN
                    --IF EXISTS
                    --(
                    --    SELECT 1
                    --    FROM appointments
                    --    WHERE slot_id = @slot_id
                    --          AND booking_type = 1
                    --          AND status = 'skipped'
                    --)
                    --BEGIN
                    --    UPDATE doctor_queue
                    --    SET current_patient_id = NULL
                    --    WHERE slot_id = @slot_id;

                    --    SELECT 1 AS success,
                    --           'Patient skipped. Skipped pending.' AS message,
                    --           @token AS token;
                    --    RETURN;
                    --END

                    UPDATE doctor_queue
                    SET
                        --queue_status = 3,
                        --             stopped_at = GETDATE(),
                        current_patient_id = NULL
                    WHERE slot_id = @slot_id;

                    SELECT 1 AS success,
                           'Last Patient Skipped' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @next_appointment_id
                      and slot_id = @slot_id;

                --------------------------------------------------
                -- UPDATE POINTER
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving = @next_queue,
                    current_patient_id = @next_patient_id
                WHERE slot_id = @slot_id;

                SELECT 1 AS success,
                       'Queue patient skipped and next started' AS message,
                       @token AS token;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW (SESSION SAFE)
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- SKIP SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'skipped'
                WHERE appointment_id = @appointment_id
                      AND booking_type = 2
                      AND status IN ( 'booked', 'in_progress' );

                IF @@ROWCOUNT = 0
                BEGIN
                    SELECT 0 AS success,
                           'Invalid active slot' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- IF NOT MOVE NEXT
                --------------------------------------------------
                IF @is_next = 0
                BEGIN
                    SELECT 1 AS success,
                           'Slot skipped.' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- FIND NEXT SLOT (SAME SESSION)
                --------------------------------------------------
                SELECT TOP 1
                    @next_appointment_id = appointment_id
                FROM appointments
                WHERE slot_id = @slot_id
                      AND booking_type = 2
                      AND status = 'booked'
                ORDER BY start_time;

                IF @next_appointment_id IS NULL
                BEGIN
                    SELECT 1 AS success,
                           'Last Patient Skipped' AS message,
                           @token AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- START NEXT SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress'
                WHERE appointment_id = @next_appointment_id;

                SELECT 1 AS success,
                       'Slot skipped and next started' AS message,
                       @token AS token;
                RETURN;
            END
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    RECALL_SESSION: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'RECALL_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET BOOKING TYPE
            --------------------------------------------------
            SELECT @booking_type = booking_type
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = CAST(GETDATE() AS DATE)
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 1
                          AND status = 'skipped'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only skipped queue patient can be recalled' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- 🔥 BLOCK: secound patient  in_progress
                --    in_progress.  current complete .
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE queue_id =
                          (SELECT queue_id FROM appointments
                           WHERE appointment_id = @appointment_id)
                          AND booking_type = 1
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- RECALL (START SESSION AGAIN)
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- UPDATE POINTER
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving =
                    (
                        SELECT queue_number
                        FROM appointments
                        WHERE appointment_id = @appointment_id
                    ),
                    current_patient_id =
                    (
                        SELECT patient_id FROM appointments WHERE appointment_id = @appointment_id
                    )
                WHERE doctor_id = @doctor_id
                      AND queue_date = CAST(GETDATE() AS DATE);

                SELECT 1 AS success,
                       'Queue patient recalled and started' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 2
                          AND status = 'skipped'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only skipped slot can be recalled' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- 🔥 BLOCK: secound slot patient  in_progress
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id =
                          (SELECT doctor_id FROM appointments
                           WHERE appointment_id = @appointment_id)
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 2
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- RECALL SLOT
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                SELECT 1 AS success,
                       'Slot recalled and started' AS message;
                RETURN;
            END
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    START_SESSION: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'START_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET APPOINTMENT
            --------------------------------------------------
            SELECT @ss_queue_number = queue_number,
                   @ss_patient_id = patient_id,
                   @booking_mode = booking_type,
                   @queue_id = queue_id
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @booking_mode IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW
            --------------------------------------------------
            IF @booking_mode = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = CAST(GETDATE() AS DATE)
                          AND queue_status = 1
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 1
                          AND status IN ( 'booked', 'skipped' )
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only booked/skipped queue can be started' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- 🔥 BLOCK: secound patient  in_progress
                --   ( 'RESET ANY ACTIVE SESSION' auto-bump )
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE queue_id = @queue_id
                          AND booking_type = 1
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START CURRENT (BY ID)
                --------------------------------------------------
                UPDATE appointments
                SET start_time = GETDATE(),
                    status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- UPDATE POINTER
                --------------------------------------------------
                UPDATE doctor_queue
                SET current_serving = @ss_queue_number,
                    current_patient_id = @ss_patient_id
                WHERE doctor_id = @doctor_id
                      AND queue_id = @queue_id
                      AND queue_date = CAST(GETDATE() AS DATE);

                SELECT 1 AS success,
                       'Queue session started' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW
            --------------------------------------------------
            IF @booking_mode = 2
            BEGIN
                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 2
                          AND status IN ( 'booked', 'skipped' )
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only booked/skipped slot can be started' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- 🔥 BLOCK: secound slot patient  in_progress
                --   ( 'RESET CURRENT ACTIVE SLOT' auto-bump )
                --------------------------------------------------
                IF EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 2
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Please complete the current in-progress patient first' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- START SLOT (BY ID)
                --------------------------------------------------
                UPDATE appointments
                SET status = 'in_progress'
                WHERE appointment_id = @appointment_id;

                SELECT 1 AS success,
                       'Slot session started' AS message;
                RETURN;
            END
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    END_SESSION: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'END_SESSION'
        BEGIN
            --------------------------------------------------
            -- GET BOOKING TYPE
            --------------------------------------------------
            SELECT @booking_type = booking_type,
                   @queue_id = queue_id
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE FLOW
            --------------------------------------------------
            IF @booking_type = 1
            BEGIN
                --------------------------------------------------
                -- CHECK QUEUE STARTED
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM doctor_queue
                    WHERE doctor_id = @doctor_id
                          AND queue_date = CAST(GETDATE() AS DATE)
                          AND queue_status = 1
                          and queue_id = @queue_id
                )
                BEGIN
                    SELECT 0 AS success,
                           'Queue not started or already stopped' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only active queue session can be ended' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- END CURRENT SESSION
                --------------------------------------------------
                UPDATE appointments
                SET end_time = GETDATE(),
                    status = 'completed'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- UPDATE COMPLETED COUNT
                --------------------------------------------------
                UPDATE doctor_queue
                SET completed_count = ISNULL(completed_count, 0) + 1
                WHERE doctor_id = @doctor_id
                      and queue_id = @queue_id
                      AND queue_date = CAST(GETDATE() AS DATE);

                --------------------------------------------------
                -- AUTO STOP CHECK
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 1
                          AND status IN ( 'booked', 'skipped' )
                )
                BEGIN
                    --UPDATE doctor_queue
                    --SET queue_status = 3,
                    --    stopped_at = GETDATE(),
                    --    current_patient_id = NULL
                    --WHERE doctor_id = @doctor_id
                    --      AND queue_date = CAST(GETDATE() AS DATE);
					   UPDATE doctor_queue
    SET current_patient_id = NULL   -- ✅  pointer clear
    WHERE doctor_id = @doctor_id
          AND queue_id = @queue_id  -- ✅ specific session
          AND queue_date = CAST(GETDATE() AS DATE);

                    SELECT 1 AS success,
                           'Queue completed' AS message,
                           NULL AS token;
                    RETURN;
                END

                --------------------------------------------------
                -- 🔥 RETURN ONLY 3rd NEXT PATIENT TOKEN
                --------------------------------------------------
                SELECT 1 AS success,
                       'Queue session ended' AS message,
                       NULL AS token,
                       NULL AS appointment_id,
                       NULL AS queue_number
                UNION ALL
                SELECT NULL,
                       NULL,
                       CASE
                           WHEN a.user_type = 1 THEN
                               p.token
                           WHEN a.user_type = 2 THEN
                               p2.token
                       END AS token,
                       a.appointment_id,
                       a.queue_number
                FROM
                (
                    SELECT *,
                           ROW_NUMBER() OVER (ORDER BY queue_number) AS rn
                    FROM appointments
                    WHERE doctor_id = @doctor_id
                          AND appointment_date = CAST(GETDATE() AS DATE)
                          AND booking_type = 1
                          AND status = 'booked'
                ) a
                    LEFT JOIN patients p
                        ON a.user_type = 1
                           AND p.patient_id = a.patient_id
                    LEFT JOIN family_members fm
                        ON a.user_type = 2
                           AND fm.member_id = a.patient_id
                    LEFT JOIN patients p2
                        ON fm.family_id = p2.patient_id
                WHERE a.rn = 3;

                RETURN;
            END

            --------------------------------------------------
            -- SLOT FLOW
            --------------------------------------------------
            IF @booking_type = 2
            BEGIN
                --------------------------------------------------
                -- VALIDATION
                --------------------------------------------------
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM appointments
                    WHERE appointment_id = @appointment_id
                          AND booking_type = 2
                          AND status = 'in_progress'
                )
                BEGIN
                    SELECT 0 AS success,
                           'Only active slot can be ended' AS message;
                    RETURN;
                END

                --------------------------------------------------
                -- END SLOT (BY ID)
                --------------------------------------------------
                UPDATE appointments
                SET status = 'completed'
                WHERE appointment_id = @appointment_id;

                --------------------------------------------------
                -- GET CURRENT CONSULTATION TIME
                --------------------------------------------------
                SELECT @consult_time = DATEDIFF(MINUTE, start_time, end_time)
                FROM appointments
                WHERE appointment_id = @appointment_id;

                IF @consult_time IS NOT NULL
                BEGIN
                    SET @hour = DATEPART(HOUR, GETDATE());

                    --------------------------------------------------
                    -- UPSERT PROFILE
                    --------------------------------------------------
                    IF NOT EXISTS (SELECT 1 FROM doctor_timing WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id))
                    BEGIN
                        INSERT INTO doctor_timing
                        (
                            doctor_id,
                            avg_consultation_time,
                            morning_avg,
                            afternoon_avg,
                            evening_avg,
                            total_completed,
                            last_updated,
                            clinic_id
                        )
                        VALUES
                        (@doctor_id, @consult_time, NULL, NULL, NULL, 1, GETDATE(), @clinic_id);
                    END
                    ELSE
                    BEGIN
                        --------------------------------------------------
                        -- UPDATE GLOBAL AVG
                        --------------------------------------------------
                        UPDATE doctor_timing
                        SET avg_consultation_time = (avg_consultation_time * total_completed + @consult_time)
                                                    / (total_completed + 1),
                            total_completed = total_completed + 1,
                            last_updated = GETDATE()
                        WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

                        --------------------------------------------------
                        -- UPDATE TIME SEGMENT AVG
                        --------------------------------------------------
                        IF @hour < 12
                        BEGIN
                            UPDATE doctor_timing
                            SET morning_avg = ISNULL((morning_avg + @consult_time) / 2, @consult_time)
                            WHERE doctor_id = @doctor_id  AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
                        END
                        ELSE IF @hour < 17
                        BEGIN
                            UPDATE doctor_timing
                            SET afternoon_avg = ISNULL((afternoon_avg + @consult_time) / 2, @consult_time)
                            WHERE doctor_id = @doctor_id  AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
                        END
                        ELSE
                        BEGIN
                            UPDATE doctor_timing
                            SET evening_avg = ISNULL((evening_avg + @consult_time) / 2, @consult_time)
                            WHERE doctor_id = @doctor_id  AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
                        END
                    END
                END

                SELECT 1 AS success,
                       'Slot completed' AS message;
                RETURN;
            END
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    RESCHEDULE_APPOINTMENT: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'RESCHEDULE_APPOINTMENT'
        BEGIN
            --------------------------------------------------
            -- VALIDATE APPOINTMENT
            --------------------------------------------------
            SELECT @old_booking_type = booking_type,
                   @old_status = status
            FROM appointments
            WHERE appointment_id = @appointment_id;

            IF @old_booking_type IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- BLOCK QUEUE RESCHEDULE
            --------------------------------------------------
            IF @old_booking_type = 1
            BEGIN
                SELECT 0 AS success,
                       'Queue appointments cannot be rescheduled' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- BLOCK INVALID STATUS
            --------------------------------------------------
            IF @old_status IN ( 'completed', 'cancelled' )
            BEGIN
                SELECT 0 AS success,
                       'Cannot reschedule completed/cancelled appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- VALIDATE SLOT AVAILABILITY
            --------------------------------------------------
            SELECT @slot_duration = ts.slot_duration,
                   @slot_start = ts.start_time,
                   @slot_end = ts.end_time
            FROM doctor_time_slots ts
                JOIN doctor_availability da
                    ON ts.availability_id = da.availability_id
            WHERE da.doctor_id = @doctor_id
                  AND da.is_enabled = 1
                  AND da.day_of_week = DATENAME(WEEKDAY, @appointment_date)
                  AND ts.booking_mode = 2
                  AND @start_time >= ts.start_time
                  AND @start_time < ts.end_time;

            IF @slot_duration IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid slot' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- VALIDATE SLOT INTERVAL
            --------------------------------------------------
            SET @minutes = DATEDIFF(MINUTE, @slot_start, @start_time);

            IF @minutes % @slot_duration <> 0
            BEGIN
                SELECT 0 AS success,
                       'Invalid slot interval' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- PREVENT DOUBLE BOOKING
            --------------------------------------------------
            IF EXISTS
            (
                SELECT 1
                FROM appointments
                WHERE doctor_id = @doctor_id
                      AND appointment_date = @appointment_date
                      AND start_time = @start_time
                      AND appointment_id <> @appointment_id
                      AND status = 'booked'
            )
            BEGIN
                SELECT 0 AS success,
                       'Slot already booked' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- UPDATE APPOINTMENT
            --------------------------------------------------
            UPDATE appointments
            SET appointment_date = @appointment_date,
                symptoms = @symptoms,
                start_time = @start_time,
                end_time = DATEADD(MINUTE, @slot_duration, @start_time),
                status = 'booked'
            WHERE appointment_id = @appointment_id;

            SELECT 1 AS success,
                   'Appointment rescheduled successfully' AS message;
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    patientAppointmentList: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

IF @operation = 'patientAppointmentList'
BEGIN
    SELECT
        vw.*,
        dq.queue_status,

        --------------------------------------------------
        -- 🔥 SESSION START TIME (FROM SLOT)
        --------------------------------------------------
        FORMAT(ts.start_time, 'hh:mm tt') AS session_start_time

    FROM dbo.appointment_booking_vw vw

    --------------------------------------------------
    -- 🔥 QUEUE JOIN (SESSION BASED)
    --------------------------------------------------
    --LEFT JOIN doctor_queue dq
    --    ON dq.doctor_id = vw.doctor_id
    --    AND dq.queue_date = CAST(GETDATE() AS DATE)
    --    AND dq.slot_id = vw.slot_id
	LEFT JOIN doctor_queue dq
    ON dq.doctor_id = vw.doctor_id
    AND dq.queue_date = CAST(GETDATE() AS DATE)
    AND dq.slot_id = vw.slot_id
    AND (@clinic_id IS NULL OR dq.clinic_id = @clinic_id)  -- ADD

    --------------------------------------------------
    -- 🔥 SESSION TIME JOIN (USING slot_id)
    --------------------------------------------------
    LEFT JOIN doctor_time_slots ts
        ON ts.slot_id = vw.slot_id
    LEFT JOIN doctor_availability da
        ON da.availability_id = ts.availability_id

    WHERE vw.doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR vw.clinic_id = @clinic_id)

    --------------------------------------------------
    -- ORDERING
    --------------------------------------------------
    ORDER BY
        vw.appointment_date,
        CASE
            WHEN vw.queue_number IS NULL THEN vw.start_time
        END,
        CASE
            WHEN vw.queue_number IS NOT NULL THEN vw.queue_number
        END;
END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    patient_Appointments: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'patient_Appointments'
        BEGIN
            SELECT *
            FROM dbo.appointment_booking_vw
            WHERE family_id = @family_id
            order by queue_number asc;
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    QUEUE_ESTIMATE_SMART: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'QUEUE_ESTIMATE_SMART'
        BEGIN
            DECLARE @base_time DATETIME;
            DECLARE @is_queue_started BIT = 0;
            DECLARE @is_my_turn BIT = 0;
            DECLARE @queue_status INT;
            DECLARE @current_slot_start TIME;

DECLARE @my_status VARCHAR(30);

            --------------------------------------------------
            -- VALIDATE APPOINTMENT + GET queue_id + slot_id
            --------------------------------------------------
            --SELECT @my_queue = queue_number,
            --       @queue_id = queue_id,
            --       @slot_id = slot_id
            --FROM appointments
            --WHERE appointment_id = @appointment_id
            --      AND booking_type = 1;

			-- VALIDATE APPOINTMENT + GET queue_id + slot_id
SELECT @my_queue = queue_number,
       @queue_id = queue_id,
       @slot_id = slot_id,
       @my_status = status
FROM appointments
WHERE appointment_id = @appointment_id
      AND booking_type = 1;

            IF @my_queue IS NULL
               OR @queue_id IS NULL
               OR @slot_id IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Invalid queue appointment' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- GET CURRENT SESSION START TIME
            --------------------------------------------------
            SELECT @current_slot_start = start_time
            FROM doctor_time_slots
            WHERE slot_id = @slot_id;

            --------------------------------------------------
            -- 🔥 GET QUEUE INFO
            ----------------------------------------------------
            --SELECT @queue_status = queue_status,
            --       @current_serving = ISNULL(current_serving, 0),
            --       @total_queue = ISNULL(total_queue, 0),
            --       @is_queue_started = CASE
            --                               WHEN queue_status = 1 THEN
            --                                   1
            --                               ELSE
            --                                   0
            --                           END
            --FROM doctor_queue
            --WHERE queue_id = @queue_id;
			SELECT @queue_status = queue_status,
       @is_queue_started = CASE
                               WHEN queue_status = 1 THEN 1
                               ELSE 0
                           END
FROM doctor_queue
WHERE queue_id = @queue_id;
SELECT @current_serving = ISNULL(MAX(a.queue_number), 0)
FROM appointments a
WHERE a.queue_id = @queue_id
  AND a.booking_type = 1
  AND a.status IN ('completed', 'in_progress', 'cancelled', 'cancled', 'skipped')
  AND NOT EXISTS (
        SELECT 1 FROM appointments b
        WHERE b.queue_id = a.queue_id
          AND b.booking_type = 1
          AND b.queue_number < a.queue_number
          AND b.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
      );

SELECT @total_queue = COUNT(*)
FROM appointments
WHERE queue_id = @queue_id
  AND booking_type = 1;

--SELECT @current_serving = ISNULL(MAX(queue_number), 0)
--FROM appointments
--WHERE queue_id = @queue_id
--  AND booking_type = 1
--  AND status IN ('completed', 'in_progress');

--SELECT @total_queue = COUNT(*)
--FROM appointments
--WHERE queue_id = @queue_id
--  AND booking_type = 1
--  AND LOWER(status) NOT IN ('cancelled', 'cancled');

            IF @is_queue_started IS NULL
                SET @is_queue_started = 0;

            --------------------------------------------------
            -- TIME-BASED AVG
            --------------------------------------------------
            SET @hour = DATEPART(HOUR, GETDATE());

            SELECT @base_avg = CASE
                                   WHEN @hour < 12 THEN
                                       morning_avg
                                   WHEN @hour < 17 THEN
                                       afternoon_avg
                                   ELSE
                                       evening_avg
                               END
            FROM doctor_timing
            WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);

            IF @base_avg IS NULL
            BEGIN
                SELECT @base_avg = avg_consultation_time
                FROM doctor_queue
                WHERE queue_id = @queue_id;
            END

            IF @base_avg IS NULL
                SET @base_avg = 7;

            --------------------------------------------------
            -- QUEUE SIZE (CURRENT SESSION)
            --------------------------------------------------
            SELECT @queue_size = COUNT(*)
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status IN ( 'booked', 'in_progress' );

            --------------------------------------------------
            -- AVG CONSULT TIME (Practo-style)
            --   measured avg, clamped to a sane 3–30 min band.
            --   NO artificial queue-size scaling.
            --------------------------------------------------
            IF @base_avg < 3  SET @base_avg = 3;
            IF @base_avg > 30 SET @base_avg = 30;

            SET @adaptive_avg = @base_avg;

            --------------------------------------------------
            -- PATIENTS AHEAD (CURRENT SESSION)
            --------------------------------------------------
            SELECT @patients_ahead = COUNT(*)
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status IN ( 'booked', 'in_progress' )
                  AND queue_number < @my_queue;

            --------------------------------------------------
            -- 🔥 PREVIOUS SESSIONS LOAD
            --------------------------------------------------
            DECLARE @previous_load INT = 0;

            --SELECT @previous_load = COUNT(*)
            --FROM appointments a
            --    JOIN doctor_queue dq2
            --        ON a.queue_id = dq2.queue_id
            --    JOIN doctor_time_slots ts2
            --        ON dq2.slot_id = ts2.slot_id
            --WHERE dq2.doctor_id = @doctor_id
            --      AND dq2.queue_date = CAST(GETDATE() AS DATE)
            --      AND a.status IN ( 'booked', 'in_progress' )
            --      AND ts2.start_time < @current_slot_start;
			SELECT @previous_load = COUNT(*)
FROM appointments a
    JOIN doctor_queue dq2 ON a.queue_id = dq2.queue_id
    JOIN doctor_time_slots ts2 ON dq2.slot_id = ts2.slot_id
WHERE dq2.doctor_id = @doctor_id
      AND dq2.clinic_id = @clinic_id        -- ← ADD THIS
      AND dq2.queue_date = CAST(GETDATE() AS DATE)
      AND a.status IN ('booked', 'in_progress')
      AND ts2.start_time < @current_slot_start;

            --------------------------------------------------
            -- WAITING (NOT-YET-STARTED) PATIENTS AHEAD IN THIS SESSION
            --------------------------------------------------
            DECLARE @waiting_ahead     INT = 0;
            DECLARE @inprogress_start  DATETIME;
            DECLARE @remaining_current FLOAT = 0;

            SELECT @waiting_ahead = COUNT(*)
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status = 'booked'
                  AND queue_number < @my_queue;

            --------------------------------------------------
            -- 🔥 CURRENT IN-PROGRESS PATIENT → only the REMAINING time counts
            --   (Practo/Qminder style: don't charge a full slot for someone
            --    the doctor is already partway through consulting.)
            --------------------------------------------------
            SELECT TOP 1 @inprogress_start = start_time
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND status = 'in_progress'
                  AND queue_number < @my_queue
            ORDER BY queue_number DESC;

            IF @inprogress_start IS NOT NULL
            BEGIN
                DECLARE @elapsed_current INT =
                    DATEDIFF(MINUTE, @inprogress_start, GETDATE());

                SET @remaining_current = @adaptive_avg - @elapsed_current;

                -- clamp: never more than a full slot, never below 1 min
                IF @remaining_current > @adaptive_avg
                    SET @remaining_current = @adaptive_avg;
                IF @remaining_current < 1
                    SET @remaining_current = 1;
            END

            --------------------------------------------------
            -- FINAL ESTIMATION
            --   earlier sessions + waiting-ahead → full avg each
            --   current in-progress patient      → remaining time only
            --------------------------------------------------
            SET @estimated_time =
                ((@previous_load + @waiting_ahead) * @adaptive_avg)
                + @remaining_current;

            --------------------------------------------------
            -- START TIME (REAL OR SCHEDULE)
            --------------------------------------------------
            SELECT TOP 1
                @started_at = start_time
            FROM appointments
            WHERE queue_id = @queue_id
                  AND booking_type = 1
                  AND start_time IS NOT NULL
            ORDER BY start_time;

            IF @started_at IS NULL
            BEGIN
                SET @started_at
                    = DATETIMEFROMPARTS(
                                           YEAR(GETDATE()),
                                           MONTH(GETDATE()),
                                           DAY(GETDATE()),
                                           DATEPART(HOUR, @current_slot_start),
                                           DATEPART(MINUTE, @current_slot_start),
                                           0,
                                           0
                                       );
            END

            IF @started_at IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Doctor not available today' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- IMMEDIATE TURN LOGIC
            --------------------------------------------------
            --IF @patients_ahead = 0
            --   AND @previous_load = 0
            --   AND @is_queue_started = 1
            --BEGIN
            --    SET @estimated_time = 0;
            --    SET @arrival_time = GETDATE();
            --    SET @is_my_turn = 1;
            --END

IF (
        @current_serving = @my_queue
        OR (@patients_ahead = 0 AND @previous_load = 0)
   )
   AND @is_queue_started = 1
   AND @my_status IN ('booked', 'in_progress')
BEGIN
    SET @estimated_time = 0;
    SET @arrival_time = GETDATE();
    SET @is_my_turn = 1;
END

            ELSE
            BEGIN
                -- Scheduled session start as today's datetime
                SET @slot_start_dt =
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()), MONTH(GETDATE()), DAY(GETDATE()),
                        DATEPART(HOUR, @current_slot_start),
                        DATEPART(MINUTE, @current_slot_start), 0, 0);

                -- Queue NOT started → nothing happens before the scheduled
                --   start, so measure from start time, never from 'now'.
                -- Queue running / doctor late → measure from now.
                IF @is_queue_started = 0 AND @slot_start_dt > GETDATE()
                    SET @base_time = @slot_start_dt;
                ELSE
                    SET @base_time = GETDATE();

                SET @arrival_time = DATEADD(MINUTE, CEILING(@estimated_time), @base_time);

                -- Never in the past
                IF @arrival_time < GETDATE()
                    SET @arrival_time = GETDATE();

                -- 🔥 Never before the scheduled start while queue not started
                IF @is_queue_started = 0 AND @arrival_time < @slot_start_dt
                    SET @arrival_time = @slot_start_dt;

                -- Round UP to next 5-min mark (clean display, like Practo)
                -- NOTE: use a midnight DATETIME (not DATE) — DATEADD(MINUTE,..)
                --       is not allowed on the DATE type.
                SET @mins_from_mid = DATEDIFF(MINUTE,
                                              DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0),
                                              @arrival_time);
                SET @arrival_time  = DATEADD(MINUTE,
                                             ((@mins_from_mid + 4) / 5) * 5,
                                             DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0));
            END

            --------------------------------------------------
            -- RESPONSE
            --------------------------------------------------
            SELECT 1 AS success,
                   @my_queue AS my_queue_number,
                   @patients_ahead AS patients_ahead,
                   @queue_size AS queue_size,
                   @total_queue AS total_queue,         -- 🔥 NEW
                   @current_serving AS current_serving, -- 🔥 NEW
                   CAST(@adaptive_avg AS DECIMAL(5, 2)) AS avg_time,
                   CASE
                       WHEN DATEDIFF(MINUTE, GETDATE(), @arrival_time) < 0 THEN 0
                       ELSE DATEDIFF(MINUTE, GETDATE(), @arrival_time)
                   END AS estimated_minutes,
                   FORMAT(@arrival_time, 'hh:mm tt') AS estimated_arrival_time,
                   @is_queue_started AS queue_started,
                   @is_my_turn AS is_my_turn,
                   CASE
                       --WHEN @queue_status = 0 THEN
                       --    'Not Started Yet'
                       --WHEN @queue_status = 1
                       --     AND @is_my_turn = 1 THEN
                       --    'Your Turn'
					    WHEN @my_status = 'skipped' THEN
        'Skipped'
    WHEN @queue_status = 0 THEN
        'Not Started Yet'
    WHEN @queue_status = 1
         AND @is_my_turn = 1 THEN
        'Your Turn'
                       WHEN @queue_status = 1 THEN
                           'Waiting'
                       WHEN @queue_status = 2 THEN
                           'Paused'
                       WHEN @queue_status = 3 THEN
                           'Queue Closed'
                       WHEN @queue_status = 4 THEN
                           'Emergency Paused'
                       ELSE
                           'Unknown'
                   END AS status;
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    QUEUE_PREVIEW_ESTIMATE: `
DECLARE @is_queue_started BIT;
DECLARE @is_my_turn BIT;
DECLARE @base_time DATETIME;
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'QUEUE_PREVIEW_ESTIMATE'
        BEGIN

            --------------------------------------------------
            -- 🔥 GET NEXT QUEUE NUMBER (NEW BOOKING)
            --------------------------------------------------
            SELECT @my_queue = ISNULL(MAX(queue_number), 0) + 1
            FROM appointments
            WHERE doctor_id = @doctor_id
                  AND appointment_date = CAST(GETDATE() AS DATE)
                  AND booking_type = 1
                  AND slot_id = @slot_id;

            --------------------------------------------------
            -- 🔥 GET CURRENT QUEUE INFO
            --------------------------------------------------
            SELECT @current_serving = ISNULL(current_patient_id, 0),
                   @queue_started_time = started_at,
                   @base_avg = avg_consultation_time
            FROM doctor_queue
            WHERE doctor_id = @doctor_id
                  AND queue_date = CAST(GETDATE() AS DATE)
                  AND slot_id = @slot_id;

            SET @current_serving = ISNULL(@current_serving, 0);

            --------------------------------------------------
            -- 🔥 PATIENTS AHEAD (REAL COUNT BASED)
            --------------------------------------------------
            SELECT @patients_ahead = COUNT(*)
            FROM appointments
            WHERE doctor_id = @doctor_id
                  AND appointment_date = CAST(GETDATE() AS DATE)
                  AND booking_type = 1
                  AND slot_id = @slot_id
                  AND status IN ( 'booked', 'in_progress' );

            SET @queue_size = @patients_ahead;

            --------------------------------------------------
            -- TIME-BASED AVG (FALLBACK)
            --------------------------------------------------
            IF @base_avg IS NULL
            BEGIN
                SET @hour = DATEPART(HOUR, GETDATE());

                SELECT @base_avg = CASE
                                       WHEN @hour < 12 THEN
                                           morning_avg
                                       WHEN @hour < 17 THEN
                                           afternoon_avg
                                       ELSE
                                           evening_avg
                                   END
                FROM doctor_timing
                WHERE doctor_id = @doctor_id AND (@clinic_id IS NULL OR clinic_id = @clinic_id);
            END

            IF @base_avg IS NULL
                SET @base_avg = 7;

            --------------------------------------------------
            -- AVG CONSULT TIME (Practo-style)
            --   measured avg, clamped to a sane 3–30 min band.
            --   NO artificial queue-size scaling.
            --------------------------------------------------
            IF @base_avg < 3  SET @base_avg = 3;
            IF @base_avg > 30 SET @base_avg = 30;

            SET @adaptive_avg = @base_avg;

            --------------------------------------------------
            -- INITIAL ESTIMATION
            --------------------------------------------------
            SET @estimated_time = @patients_ahead * @adaptive_avg;

            --------------------------------------------------
            -- START TIME (REAL OR SCHEDULE)
            --------------------------------------------------

            -- REAL START
            SET @started_at = @queue_started_time;

            -- FALLBACK → SLOT TIME
            IF @started_at IS NULL
            BEGIN
                SELECT TOP 1
                    @started_at
                        = DATETIMEFROMPARTS(
                                               YEAR(GETDATE()),
                                               MONTH(GETDATE()),
                                               DAY(GETDATE()),
                                               DATEPART(HOUR, ts.start_time),
                                               DATEPART(MINUTE, ts.start_time),
                                               0,
                                               0
                                           )
                FROM doctor_time_slots ts
                WHERE ts.slot_id = @slot_id;
            END

            IF @started_at IS NULL
            BEGIN
                SELECT 0 AS success,
                       'Doctor not available today' AS message;
                RETURN;
            END

            --------------------------------------------------
            -- QUEUE STARTED CHECK
            --------------------------------------------------
            IF @started_at <= GETDATE()
                SET @is_queue_started = 1;
            ELSE
                SET @is_queue_started = 0;

            --------------------------------------------------
            -- FINAL ARRIVAL TIME
            --------------------------------------------------
            IF @patients_ahead = 0
               AND @is_queue_started = 1
            BEGIN
                SET @estimated_time = 0;
                SET @arrival_time = GETDATE();
                SET @is_my_turn = 1;
            END
            ELSE
            BEGIN
                -- Scheduled session start as today's datetime
                SELECT @slot_start_dt =
                    DATETIMEFROMPARTS(
                        YEAR(GETDATE()), MONTH(GETDATE()), DAY(GETDATE()),
                        DATEPART(HOUR, ts.start_time),
                        DATEPART(MINUTE, ts.start_time), 0, 0)
                FROM doctor_time_slots ts
                WHERE ts.slot_id = @slot_id;

                -- Queue NOT started → measure from scheduled start, not 'now'.
                IF @is_queue_started = 0
                   AND @slot_start_dt IS NOT NULL
                   AND @slot_start_dt > GETDATE()
                    SET @base_time = @slot_start_dt;
                ELSE
                    SET @base_time = GETDATE();

                SET @arrival_time = DATEADD(MINUTE, CEILING(@estimated_time), @base_time);

                -- Never in the past
                IF @arrival_time < GETDATE()
                    SET @arrival_time = GETDATE();

                -- 🔥 Never before the scheduled start while queue not started
                IF @is_queue_started = 0
                   AND @slot_start_dt IS NOT NULL
                   AND @arrival_time < @slot_start_dt
                    SET @arrival_time = @slot_start_dt;

                -- Round UP to next 5-min mark (clean display, like Practo)
                -- NOTE: use a midnight DATETIME (not DATE) — DATEADD(MINUTE,..)
                --       is not allowed on the DATE type.
                SET @mins_from_mid = DATEDIFF(MINUTE,
                                              DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0),
                                              @arrival_time);
                SET @arrival_time  = DATEADD(MINUTE,
                                             ((@mins_from_mid + 4) / 5) * 5,
                                             DATEADD(DAY, DATEDIFF(DAY, 0, @arrival_time), 0));
            END

            --------------------------------------------------
            -- RESPONSE
            --------------------------------------------------
            SELECT 1 AS success,
                   @my_queue AS predicted_queue_number,
                   @patients_ahead AS patients_ahead,
                   @queue_size AS current_queue_size,
                   CAST(@adaptive_avg AS DECIMAL(5, 2)) AS avg_time,
                   CASE
                       WHEN DATEDIFF(MINUTE, GETDATE(), @arrival_time) < 0 THEN 0
                       ELSE DATEDIFF(MINUTE, GETDATE(), @arrival_time)
                   END AS estimated_minutes,
                   FORMAT(@arrival_time, 'hh:mm tt') AS estimated_arrival_time,
                   @is_queue_started AS queue_started,
                   @is_my_turn AS is_my_turn,
                   CASE
                       WHEN @is_queue_started = 0 THEN
                           'Not Started Yet'
                       WHEN @is_my_turn = 1 THEN
                           'Your Turn'
                       ELSE
                           'Waiting'
                   END AS status;
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    TOMORROW_PATIENT_APPOINTMENTS: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'TOMORROW_PATIENT_APPOINTMENTS'
        BEGIN
            SELECT a.appointment_id,
                   a.appointment_date,
                   d.name AS doctor_name,
                   p.token AS patient_token
            FROM appointments a
                INNER JOIN doctor_login d
                    ON d.doctor_id = a.doctor_id
                INNER JOIN patients p
                    ON p.patient_id = a.patient_id
            WHERE CAST(a.appointment_date AS DATE) = CAST(DATEADD(DAY, 1, GETDATE()) AS DATE)
            ORDER BY a.queue_number;
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,

    YESTERDAY_COMPLETED_PATIENTS: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        IF @operation = 'YESTERDAY_COMPLETED_PATIENTS'
        BEGIN
            SELECT a.appointment_id,
                   a.appointment_date,
                   a.queue_number,
                   d.name AS doctor_name,
                   CASE
                       WHEN a.user_type = 2 THEN
                           p_main.token
                       ELSE
                           p.token
                   END AS patient_token
            FROM appointments a
                INNER JOIN doctor_login d
                    ON d.doctor_id = a.doctor_id

                -- Direct patient (user_type = 1)
                LEFT JOIN patients p
                    ON p.patient_id = a.patient_id
                       AND a.user_type <> 2

                -- For family member (user_type = 2)
                LEFT JOIN family_members fm
                    ON fm.member_id = a.patient_id
                       AND a.user_type = 2

                -- Get token using family_id (main member)
                LEFT JOIN patients p_main
                    ON p_main.patient_id = fm.family_id
                       AND a.user_type = 2
            WHERE CAST(a.appointment_date AS DATE) = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE)
                  AND a.status = 'completed'
            ORDER BY a.queue_number;
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,
  },
  // any other @operation value (the procedure ran none of its branches)
  other: `
BEGIN
    SET NOCOUNT ON;

    DECLARE @booking_mode INT,
            @slot_duration INT,
            @slot_start TIME,
            @slot_end TIME,
            @minutes INT,
            @next_queue INT,
            @temp_slot int,
            @total_queue int,
            @max_queue_length int;

    DECLARE @day NVARCHAR(20);

    DECLARE @start_date DATE;
    DECLARE @end_date DATE;

    DECLARE @booking_type INT;
    DECLARE @current_queue INT;
    DECLARE @next_patient_id INT;
    DECLARE @next_appointment_id INT;

    DECLARE @current_serving INT;
    DECLARE @qn_next_queue INT;
    DECLARE @qn_next_patient_id INT;

    DECLARE @skip_current_serving INT;
    DECLARE @skip_next_queue INT;
    DECLARE @skip_next_patient_id INT;

    DECLARE @recall_queue_number INT;

    DECLARE @my_queue INT;
    DECLARE @patients_ahead INT;
    DECLARE @estimated_wait INT;

    DECLARE @old_booking_type INT;
    DECLARE @old_status NVARCHAR(50);

    DECLARE @ss_queue_number INT;
    DECLARE @ss_patient_id INT;

    DECLARE @es_current_serving INT;
    DECLARE @consult_time INT;
    DECLARE @hour INT;

    DECLARE @avg_time INT;

    DECLARE @base_avg FLOAT;
    DECLARE @adaptive_avg FLOAT;
    DECLARE @queue_size INT;
    DECLARE @estimated_time FLOAT;
    DECLARE @started_at DATETIME;
    DECLARE @time_passed INT;
    DECLARE @expected_completed FLOAT;
    DECLARE @actual_completed INT;
    DECLARE @delay_count FLOAT;
    DECLARE @adjustment FLOAT;
    DECLARE @arrival_time DATETIME;
    DECLARE @multiplier FLOAT;
    DECLARE @queue_started_time DATETIME;
    DECLARE @slot_start_dt DATETIME;
    DECLARE @mins_from_mid INT;

    BEGIN TRY

        SET NOCOUNT ON;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SELECT 0 AS success,
               ERROR_MESSAGE() AS message;
    END CATCH
END
`,
};
