// SQL moved from the stored procedure sp_doctor_login (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/doctors'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'sp_doctor_login',
  params: [
    { name: 'operation', type: 'NVARCHAR(50)', default: null },
    { name: 'doctor_id', type: 'INT', default: 'NULL' },
    { name: 'name', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'email', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'mobile', type: 'NVARCHAR(20)', default: 'NULL' },
    { name: 'qualification', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'license_no', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'experience', type: 'INT', default: 'NULL' },
    { name: 'specialization', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'role_id', type: 'INT', default: 'NULL' },
    { name: 'gender_id', type: 'INT', default: 'NULL' },
    { name: 'q_start_before', type: 'INT', default: 'NULL' },
    { name: 'role', type: 'NVARCHAR(20)', default: 'NULL' },
    { name: 'token', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'image', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'clinic_id', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'clinic_name', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'clinic_address', type: 'NVARCHAR(100)', default: 'NULL' },
    { name: 'latitude', type: 'DECIMAL(10,7)', default: 'NULL' },
    { name: 'longitude', type: 'DECIMAL(10,7)', default: 'NULL' },
    { name: 'consultation_fee', type: 'DECIMAL(10,2)', default: 'NULL' },
    { name: 'website_name', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'clinic_email', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'clinic_contact', type: 'NVARCHAR(20)', default: 'NULL' },
    { name: 'image_url', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'sort_order', type: 'INT', default: 'NULL' },
  ],
  ops: {
    Insert: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'Insert'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (
            SELECT 1 FROM dbo.doctor_login
            WHERE mobile = @mobile AND active_status = 0
        )
        BEGIN
            SELECT 0 AS success, 'Mobile number already exists' AS message;
            ROLLBACK TRANSACTION;
            RETURN;
        END
		IF EXISTS (
    SELECT 1 FROM dbo.receptionist
    WHERE mobile_no = @mobile AND active_status = 1
)
BEGIN
    SELECT 0 AS success, 'This mobile is already registered as a Receptionist' AS message;
    ROLLBACK TRANSACTION;
    RETURN;
END

        DECLARE @next_no INT;
        SELECT @next_no = ISNULL(MAX(CAST(SUBSTRING(clinic_id,3,10) AS INT)),0) + 1
        FROM dbo.clinics WHERE clinic_id LIKE 'CL%';
        SET @clinic_id = 'CL' + RIGHT('000' + CAST(@next_no AS NVARCHAR), 3);

        INSERT INTO dbo.clinics
            (clinic_id, clinic_name, clinic_address, latitude, longitude,
             consultation_fee, website_name, clinic_email, clinic_contact,
             image_url, active_status, is_verified)
        VALUES
            (@clinic_id, @clinic_name, @clinic_address, @latitude, @longitude,
             @consultation_fee, @website_name, @clinic_email, @clinic_contact,
             @image_url, 0, 1);

        -- is_verified here: 1 = pending admin review, 0 = verified (VerifyDoctor
        -- sets 0). Review happens in the background and restricts nothing; only
        -- active_status <> 0 (admin Reject / block) does.
        INSERT INTO dbo.doctor_login
            (name, email, mobile, qualification, license_no, experience,
             specialization, created_at, role_id, clinic_id,
             active_status, is_verified, gender_id, image)
        VALUES
            (@name, @email, @mobile, @qualification, @license_no, @experience,
             @specialization, GETDATE(), @role_id, @clinic_id,
             0, 1, @gender_id, @image);

        SET @doctor_id = SCOPE_IDENTITY();

        UPDATE dbo.clinics
        SET doctor_id = @doctor_id
        WHERE clinic_id = @clinic_id;

        COMMIT TRANSACTION;
        SELECT @doctor_id AS doctor_id, @clinic_id AS clinic_id;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
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

        UPDATE dbo.doctor_login
        SET name = @name, email = @email, mobile = @mobile,
            qualification = @qualification, license_no = @license_no,
            experience = @experience, specialization = @specialization,
            role_id = @role_id, gender_id = @gender_id
        WHERE doctor_id = @doctor_id;

        UPDATE dbo.clinics
        SET clinic_name = @clinic_name, clinic_address = @clinic_address,
            latitude = @latitude, longitude = @longitude,
            consultation_fee = @consultation_fee, website_name = @website_name,
            clinic_email = @clinic_email, clinic_contact = @clinic_contact,
            image_url = @image_url
        WHERE clinic_id = (SELECT clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id);

        COMMIT TRANSACTION;

        DECLARE @returned_clinic_id NVARCHAR(50);
        SELECT @returned_clinic_id = clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id;
        SELECT @doctor_id AS doctor_id, @returned_clinic_id AS clinic_id;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
    END CATCH
    RETURN;
END

END
`,

    saveFirebaseToken: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'saveFirebaseToken'
BEGIN
    IF @role = 'doctor'
        UPDATE doctor_login SET token = @token WHERE mobile = @mobile;
    ELSE IF @role = 'patient'
        UPDATE Patients SET token = @token WHERE mobile_no = @mobile;
    RETURN;
END

END
`,

    FetchDoctors: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'FetchDoctors'
BEGIN
    SELECT * FROM dbo.doctor_login
    WHERE clinic_id = @clinic_id AND active_status = 0;
    RETURN;
END

END
`,

    DeleteDoctor: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'DeleteDoctor'
BEGIN
    UPDATE dbo.doctor_login SET active_status = 1 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor deleted successfully' AS message;
    RETURN;
END

END
`,

    ListPendingDoctors: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'ListPendingDoctors'
BEGIN
    SELECT doctor_id, name, email, mobile, qualification, license_no,
           experience, specialization, clinic_id, clinic_name,
           clinic_address, clinic_contact, clinic_email, doc_created_at
    FROM dbo.doctor_login_vw
    WHERE doc_active_status = 0 AND doc_is_verified = 1
    ORDER BY doc_created_at ASC;
    RETURN;
END

END
`,

    VerifyDoctor: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'VerifyDoctor'
BEGIN
    UPDATE dbo.doctor_login SET is_verified = 0 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor verified' AS message;
    RETURN;
END

END
`,

    check_phone_doctor: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'check_phone_doctor'
BEGIN
    SELECT * FROM dbo.doctor_login_vw
    -- active (not blocked) doctors; pending verification may log in
    WHERE mobile = @mobile AND doc_active_status = 0;
    RETURN;
END

END
`,

    doctor_mobile_exist: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'doctor_mobile_exist'
BEGIN
    SELECT doctor_id, mobile, doc_active_status, doc_is_verified
    FROM dbo.doctor_login_vw
    WHERE mobile = @mobile AND doc_active_status = 0

    UNION ALL

    SELECT NULL AS doctor_id, mobile_no AS mobile, 1 AS doc_active_status, 1 AS doc_is_verified
    FROM dbo.receptionist
    WHERE mobile_no = @mobile AND active_status = 1;
    RETURN;
END

END
`,

    uploadDoctorImg: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'uploadDoctorImg'
BEGIN
    UPDATE doctor_login SET image = @image WHERE doctor_id = @doctor_id;
    RETURN;
END

END
`,

    uploadClinicGallery: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'uploadClinicGallery'
BEGIN
    INSERT INTO dbo.clinic_images
        (clinic_id, image_url, sort_order, active_status, created_at)
    VALUES (@clinic_id, @image_url, @sort_order, 0, GETDATE());
    RETURN;
END

END
`,

    Insert_Q_StartTime: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'Insert_Q_StartTime'
BEGIN
    UPDATE doctor_login SET q_start_before = @q_start_before WHERE doctor_id = @doctor_id;
    RETURN;
END

END
`,

    fetchClinicGallery: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'fetchClinicGallery'
BEGIN
    SELECT clinic_image_id, clinic_id, image_url, sort_order
    FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id AND active_status = 0
    ORDER BY sort_order;
    RETURN;
END

END
`,

    deleteClinicGallery: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'deleteClinicGallery'
BEGIN
    DELETE FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id
      AND image_url IN (SELECT value FROM STRING_SPLIT(@image_url, ','));
    SELECT @@ROWCOUNT AS deleted_count, 'Images deleted' AS message;
    RETURN;
END

END
`,

    AddClinic: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'AddClinic'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @next_no2 INT;
        SELECT @next_no2 = ISNULL(MAX(CAST(SUBSTRING(clinic_id,3,10) AS INT)),0) + 1
        FROM dbo.clinics WHERE clinic_id LIKE 'CL%';
        SET @clinic_id = 'CL' + RIGHT('000' + CAST(@next_no2 AS NVARCHAR), 3);

        INSERT INTO dbo.clinics
            (clinic_id, clinic_name, clinic_address, latitude, longitude,
             consultation_fee, website_name, clinic_email, clinic_contact,
             image_url, active_status, is_verified, doctor_id)
        VALUES
            (@clinic_id, @clinic_name, @clinic_address, @latitude, @longitude,
             @consultation_fee, @website_name, @clinic_email, @clinic_contact,
             @image_url, 0, 1, @doctor_id);

        COMMIT TRANSACTION;
        SELECT 1 AS success, @clinic_id AS clinic_id, 'Clinic added' AS message;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
    RETURN;
END

END
`,

    GetDoctorClinics: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'GetDoctorClinics'
BEGIN
    SELECT
        clinic_id, clinic_name, clinic_address,
        latitude, longitude, consultation_fee,
        clinic_email, clinic_contact,
        website_name, image_url,
        CASE WHEN clinic_id = (
            SELECT clinic_id FROM dbo.doctor_login WHERE doctor_id = @doctor_id
        ) THEN 1 ELSE 0 END AS is_primary
    FROM dbo.clinics
    WHERE doctor_id = @doctor_id
      AND active_status = 0
    ORDER BY is_primary DESC;
    RETURN;
END

END
`,

    UpdateClinic: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'UpdateClinic'
BEGIN
    UPDATE dbo.clinics
    SET clinic_name      = @clinic_name,
        clinic_address   = @clinic_address,
        latitude         = ISNULL(@latitude, latitude),
        longitude        = ISNULL(@longitude, longitude),
        consultation_fee = @consultation_fee,
        website_name     = @website_name,
        clinic_email     = @clinic_email,
        clinic_contact   = @clinic_contact
    WHERE clinic_id = @clinic_id
      AND doctor_id = @doctor_id;
    SELECT 1 AS success, @clinic_id AS clinic_id;
    RETURN;
END

END
`,

    DeleteClinic: `
BEGIN
SET NOCOUNT ON;

IF @operation = 'DeleteClinic'
BEGIN
    -- Primary clinic (doctor_login.clinic_id shi match) delete nahi hoto
    IF EXISTS (
        SELECT 1 FROM dbo.doctor_login
        WHERE doctor_id = @doctor_id AND clinic_id = @clinic_id
    )
    BEGIN
        SELECT 0 AS success, 'Cannot delete primary clinic' AS message;
        RETURN;
    END

    UPDATE dbo.clinics
    SET active_status = 1
    WHERE clinic_id = @clinic_id
      AND doctor_id = @doctor_id;

    SELECT 1 AS success, 'Clinic deleted' AS message;
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
