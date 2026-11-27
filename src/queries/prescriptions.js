// SQL moved from the stored procedure sp_prescription (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/prescriptions'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'sp_prescription',
  params: [
    { name: 'operation', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'prescription_id', type: 'INT', default: '0' },
    { name: 'patient_id', type: 'INT', default: '0' },
    { name: 'doctor_id', type: 'INT', default: 'NULL' },
    { name: 'prescription_date', type: 'DATETIME', default: 'NULL' },
    { name: 'symptoms', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'diagnosis', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'clinical_notes', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'follow_up_date', type: 'DATE', default: 'NULL' },
    { name: 'follow_up_time', type: 'TIME(0)', default: 'NULL' }, // migration 015
    { name: 'advice', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'investigation', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'created_at', type: 'DATETIME', default: 'NULL' },
    { name: 'user_type', type: 'INT', default: '0' },
    { name: 'presc_med_id', type: 'INT', default: '0' },
    { name: 'medicine_id', type: 'INT', default: 'NULL' },
    { name: 'medicine_type_id', type: 'INT', default: 'NULL' },
    { name: 'frequency', type: 'VARCHAR(50)', default: 'NULL' },
    { name: 'duration', type: 'VARCHAR(50)', default: 'NULL' },
    { name: 'timing', type: 'VARCHAR(50)', default: 'NULL' },
    { name: 'tablet_dosage', type: 'VARCHAR(20)', default: 'NULL' },
    { name: 'syrup_dosage_ml', type: 'VARCHAR(20)', default: 'NULL' },
    { name: 'inj_dosage', type: 'VARCHAR(20)', default: 'NULL' },
    { name: 'inj_route', type: 'VARCHAR(20)', default: 'NULL' },
    { name: 'drops_count', type: 'VARCHAR(10)', default: 'NULL' },
    { name: 'drops_application', type: 'VARCHAR(20)', default: 'NULL' },
    { name: 'lotion_apply_area', type: 'VARCHAR(50)', default: 'NULL' },
    { name: 'spray_puffs', type: 'VARCHAR(20)', default: 'NULL' },
    { name: 'spray_usage', type: 'VARCHAR(20)', default: 'NULL' },
    { name: 'lotion_usage', type: 'VARCHAR(50)', default: 'NULL' },
    { name: 'powder_dosage', type: 'VARCHAR(20)', default: 'NULL' },
    { name: 'powder_form', type: 'VARCHAR(50)', default: 'NULL' },
    { name: 'inhaler_puffs', type: 'VARCHAR(20)', default: 'NULL' },
    { name: 'inhaler_type', type: 'VARCHAR(30)', default: 'NULL' },
    { name: 'inhaler_technique', type: 'VARCHAR(50)', default: 'NULL' },
    { name: 'inhaler_usage', type: 'VARCHAR(50)', default: 'NULL' },
    { name: 'appointment_id', type: 'INT', default: '0' },
    { name: 'clinic_id', type: 'NVARCHAR(20)', default: 'NULL' },
    // clinic stock (migration 013)
    { name: 'source', type: 'VARCHAR(10)', default: 'NULL' },
    { name: 'administered_at_clinic', type: 'BIT', default: '0' },
    { name: 'qty_given', type: 'DECIMAL(10,2)', default: 'NULL' },
    { name: 'unit_price', type: 'DECIMAL(10,2)', default: 'NULL' },
    { name: 'created_by_id', type: 'INT', default: 'NULL' },
    { name: 'created_by_role', type: 'TINYINT', default: 'NULL' },
  ],
  ops: {
    Insert: `
BEGIN
    SET NOCOUNT ON;

 IF @operation = 'Insert'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @prescription_id = 0
        BEGIN
            INSERT INTO dbo.patient_records
            (patient_id, doctor_id, prescription_date, symptoms, diagnosis,
             clinical_notes, follow_up_date, follow_up_time, advice, investigation, created_at, user_type, appointment_id,clinic_id)
            VALUES
            (@patient_id, @doctor_id, ISNULL(@prescription_date, GETDATE()),
             @symptoms, @diagnosis, @clinical_notes, @follow_up_date, @follow_up_time,
             @advice, @investigation, ISNULL(@created_at, GETDATE()), @user_type, @appointment_id,@clinic_id);

            SET @prescription_id = SCOPE_IDENTITY();
        END

        IF @medicine_id IS NOT NULL
        BEGIN
            -- Price: what the doctor typed, else the clinic's sale price
            IF @source = 'clinic' AND @unit_price IS NULL
                SELECT @unit_price = sale_price FROM dbo.Clinic_Medicine
                WHERE clinic_id = @clinic_id AND medicine_id = @medicine_id;

            INSERT INTO dbo.PrescriptionMedicine
                (prescription_id, medicine_id, medicine_type_id, frequency, duration,
                 timing, tablet_dosage, syrup_dosage_ml, inj_dosage, inj_route,
                 drops_count, drops_application, lotion_apply_area, spray_puffs,
                 spray_usage, lotion_usage,
                 powder_dosage, powder_form,
                 inhaler_puffs, inhaler_type, inhaler_technique, inhaler_usage,
                 source, administered_at_clinic, qty_given, unit_price)
                VALUES
                (@prescription_id, @medicine_id, @medicine_type_id, @frequency, @duration,
                 @timing, @tablet_dosage, @syrup_dosage_ml, @inj_dosage, @inj_route,
                 @drops_count, @drops_application, @lotion_apply_area, @spray_puffs,
                 @spray_usage, @lotion_usage,
                 @powder_dosage, @powder_form,
                 @inhaler_puffs, @inhaler_type, @inhaler_technique, @inhaler_usage,
                 @source, ISNULL(@administered_at_clinic, 0), @qty_given, @unit_price);

            SET @presc_med_id = SCOPE_IDENTITY();

            -- Given from clinic stock: take it out (stock may go negative on purpose)
            IF @source = 'clinic' AND @qty_given > 0
            BEGIN
                INSERT INTO dbo.Clinic_Medicine (clinic_id, medicine_id)
                SELECT @clinic_id, @medicine_id
                WHERE NOT EXISTS (SELECT 1 FROM dbo.Clinic_Medicine WITH (UPDLOCK, HOLDLOCK)
                                  WHERE clinic_id = @clinic_id AND medicine_id = @medicine_id);

                INSERT INTO dbo.Clinic_Stock_Movement
                    (clinic_id, medicine_id, qty, reason, presc_med_id, created_by_id, created_by_role)
                VALUES
                    (@clinic_id, @medicine_id, -@qty_given,
                     CASE WHEN @administered_at_clinic = 1 THEN 'administer' ELSE 'dispense' END,
                     @presc_med_id, @created_by_id, @created_by_role);
            END
        END

        --------------------------------------------------
        -- 🔥 GET TOKEN (PATIENT / FAMILY)
        --------------------------------------------------
        DECLARE @token NVARCHAR(MAX) = NULL;

        IF @user_type = 1
        BEGIN
            SELECT @token = token
            FROM patients
            WHERE patient_id = @patient_id;
        END
        ELSE IF @user_type = 2
        BEGIN
            SELECT @token = p.token
            FROM family_members fm
            JOIN patients p ON fm.family_id = p.patient_id
            WHERE fm.member_id = @patient_id;
        END

        COMMIT TRANSACTION;

        --------------------------------------------------
        -- ✅ FINAL RESPONSE
        --------------------------------------------------
        SELECT
            1 AS success,
            'Prescription created' AS message,
            @prescription_id AS prescription_id,
            @token AS token;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT
            0 AS success,
            ERROR_MESSAGE() AS message,
            NULL AS prescription_id,
            NULL AS token;
    END CATCH
END

BEGIN
    SELECT 'Invalid Operation' AS message
END
END
`,

    FollowUpReminders: `
BEGIN
    SET NOCOUNT ON;

	IF @operation = 'FollowUpReminders'
BEGIN
    SELECT
        pr.prescription_id,
        pr.appointment_id,
        pr.doctor_id,
        pr.follow_up_date,
        CONVERT(char(5), pr.follow_up_time, 108) AS follow_up_time,
        CASE
            WHEN pr.follow_up_date = CAST(GETDATE() AS DATE)
                THEN 'day_of'
            WHEN pr.follow_up_date = CAST(DATEADD(DAY, 1, GETDATE()) AS DATE)
                THEN 'day_before'
        END AS reminder_kind,
        (SELECT TOP 1 v.doctor_name
           FROM dbo.prescription_vw v
          WHERE v.prescription_id = pr.prescription_id) AS doctor_name,
        CASE
            WHEN pr.user_type = 1 THEN p1.token
            WHEN pr.user_type = 2 THEN p2.token
        END AS patient_token
    FROM dbo.patient_records pr
    LEFT JOIN patients p1
           ON pr.user_type = 1 AND p1.patient_id = pr.patient_id
    LEFT JOIN family_members fm
           ON pr.user_type = 2 AND fm.member_id = pr.patient_id
    LEFT JOIN patients p2
           ON pr.user_type = 2 AND p2.patient_id = fm.family_id
    WHERE pr.follow_up_date IN (
              CAST(GETDATE() AS DATE),
              CAST(DATEADD(DAY, 1, GETDATE()) AS DATE)
          );
END

BEGIN
    SELECT 'Invalid Operation' AS message
END
END
`,

    PatientPrescriptionList: `
BEGIN
    SET NOCOUNT ON;

IF @operation = 'PatientPrescriptionList'
BEGIN
    SELECT DISTINCT
        prescription_id,
        patient_id,
        patient_name,
        user_type,
        user_type_name,

        doctor_id,
        doctor_name as name,
        qualification,
        specialization,

        prescription_date,
        symptoms,
        diagnosis,
        clinical_notes,
        follow_up_date,
        follow_up_time,
        advice,
        investigation,
        created_at,

        clinic_name,
        clinic_address,
        clinic_contact

    FROM dbo.prescription_vw

    WHERE
      (
        -- 👤 Self
        patient_id = @patient_id

        OR

        -- 👨‍👩‍👧 Family Members
        patient_id IN (
            SELECT member_id
            FROM family_members
            WHERE family_id = @patient_id
        )
      )
      -- Clinic staff: only their own doctor's prescriptions (NULL for the patient app)
      AND (@doctor_id IS NULL OR doctor_id = @doctor_id)

    ORDER BY prescription_date DESC
END

ELSE
BEGIN
    SELECT 'Invalid Operation' AS message
END
END
`,

    PrescriptionDetail: `
BEGIN
    SET NOCOUNT ON;

IF @operation = 'PrescriptionDetail'
BEGIN
    SELECT *
    FROM dbo.prescription_vw
    WHERE prescription_id = @prescription_id
END

ELSE
BEGIN
    SELECT 'Invalid Operation' AS message
END
END
`,

    AppointmentWisePrescription: `
BEGIN
    SET NOCOUNT ON;

IF @operation = 'AppointmentWisePrescription'
BEGIN
    SELECT *
    FROM dbo.prescription_vw
    WHERE appointment_id = @appointment_id
END

ELSE
BEGIN
    SELECT 'Invalid Operation' AS message
END
END
`,
  },
  // any other @operation value (the procedure ran none of its branches)
  other: `
BEGIN
    SET NOCOUNT ON;

BEGIN
    SELECT 'Invalid Operation' AS message
END
END
`,
};
