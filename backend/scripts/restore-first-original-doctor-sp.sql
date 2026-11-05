-- Restores the ORIGINAL (pre 4-Nov) doctor login behaviour:
--   is_verified = 0  -> APPROVED  (doctor can log in)
--   is_verified = 1  -> PENDING   (app shows "Under Verification")
-- A newly registered doctor gets is_verified = 1 (pending). To let them in,
-- set it to 0 by hand: UPDATE dbo.doctor_login SET is_verified = 0 WHERE doctor_id = <id>;
-- check_phone_doctor requires doc_is_verified = 0 (unchanged from the original).
-- The ListPendingDoctors / VerifyDoctor operations are kept (so backend
-- /admin routes do not break) but use the original meaning (1 = pending).
--
-- Requires the app's login_screen.dart check to be `isverified == 1` => block.
--
-- STEP 1: run this whole file (Execute).
-- STEP 2: run the data fix at the bottom (read it first).

USE [QLess]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_doctor_login]
(
    @operation          NVARCHAR(50),
    @doctor_id          INT = NULL,
    @name               NVARCHAR(50) = NULL,
    @email              NVARCHAR(MAX) = NULL,
    @mobile             NVARCHAR(20) = NULL,
    @qualification      NVARCHAR(MAX) = NULL,
    @license_no         NVARCHAR(50) = NULL,
    @experience         INT = NULL,
    @specialization     NVARCHAR(50) = NULL,
    @role_id            INT = NULL,
    @gender_id          INT = NULL,
    @q_start_before     INT = NULL,
    @role               NVARCHAR(20) = NULL,
    @token              NVARCHAR(MAX) = NULL,
    @image              NVARCHAR(MAX) = NULL,
    @clinic_id          NVARCHAR(50) = NULL,
    @clinic_name        NVARCHAR(50) = NULL,
    @clinic_address     NVARCHAR(100) = NULL,
    @latitude           DECIMAL(10,7) = NULL,
    @longitude          DECIMAL(10,7) = NULL,
    @consultation_fee   DECIMAL(10,2) = NULL,
    @website_name       NVARCHAR(50) = NULL,
    @clinic_email       NVARCHAR(MAX) = NULL,
    @clinic_contact     NVARCHAR(20) = NULL,
    @image_url          NVARCHAR(MAX) = NULL,
    @sort_order         INT = NULL
)
AS
BEGIN
SET NOCOUNT ON;

---------------------------------------------------------
-- INSERT
---------------------------------------------------------
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

        -- is_verified = 1: a freshly-registered doctor starts as pending
        -- ("Under Verification" at login) until it is set to 0 by hand
        -- (original behaviour).
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

---------------------------------------------------------
-- saveFirebaseToken
---------------------------------------------------------
IF @operation = 'saveFirebaseToken'
BEGIN
    IF @role = 'doctor'
        UPDATE doctor_login SET token = @token WHERE mobile = @mobile;
    ELSE IF @role = 'patient'
        UPDATE Patients SET token = @token WHERE mobile_no = @mobile;
    RETURN;
END

---------------------------------------------------------
-- UPDATE
---------------------------------------------------------
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

---------------------------------------------------------
-- FetchDoctor
---------------------------------------------------------
IF @operation = 'FetchDoctor'
BEGIN
    SELECT d.doctor_id, d.name, d.email, d.mobile, d.qualification,
           d.license_no, d.experience, d.specialization, d.clinic_id,
           c.clinic_name, c.clinic_address, c.consultation_fee,
           c.clinic_contact, c.clinic_email
    FROM dbo.doctor_login d
    LEFT JOIN dbo.clinics c ON d.clinic_id = c.clinic_id
    WHERE d.mobile = @mobile;
    RETURN;
END

---------------------------------------------------------
-- FetchDoctors
---------------------------------------------------------
IF @operation = 'FetchDoctors'
BEGIN
    SELECT * FROM dbo.doctor_login
    WHERE clinic_id = @clinic_id AND active_status = 0;
    RETURN;
END

---------------------------------------------------------
-- DeleteDoctor
---------------------------------------------------------
IF @operation = 'DeleteDoctor'
BEGIN
    UPDATE dbo.doctor_login SET active_status = 1 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor deleted successfully' AS message;
    RETURN;
END

---------------------------------------------------------
-- ListPendingDoctors - blocked/pending doctors (1 = pending)
---------------------------------------------------------
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

---------------------------------------------------------
-- VerifyDoctor - approval (0 = approved)
---------------------------------------------------------
IF @operation = 'VerifyDoctor'
BEGIN
    UPDATE dbo.doctor_login SET is_verified = 0 WHERE doctor_id = @doctor_id;
    SELECT 1 AS success, 'Doctor verified' AS message;
    RETURN;
END

---------------------------------------------------------
-- check_phone_doctor (approved doctors only: 0 = approved) - original
---------------------------------------------------------
IF @operation = 'check_phone_doctor'
BEGIN
    SELECT * FROM dbo.doctor_login_vw
    WHERE mobile = @mobile AND doc_active_status = 0 AND doc_is_verified = 0;
    RETURN;
END

---------------------------------------------------------
-- doctor_mobile_exist
---------------------------------------------------------
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

---------------------------------------------------------
-- uploadDoctorImg
---------------------------------------------------------
IF @operation = 'uploadDoctorImg'
BEGIN
    UPDATE doctor_login SET image = @image WHERE doctor_id = @doctor_id;
    RETURN;
END

---------------------------------------------------------
-- uploadClinicImg
---------------------------------------------------------
IF @operation = 'uploadClinicImg'
BEGIN
    UPDATE clinics SET image_url = @image_url WHERE clinic_id = @clinic_id;
    RETURN;
END

---------------------------------------------------------
-- uploadClinicGallery
---------------------------------------------------------
IF @operation = 'uploadClinicGallery'
BEGIN
    INSERT INTO dbo.clinic_images
        (clinic_id, image_url, sort_order, active_status, created_at)
    VALUES (@clinic_id, @image_url, @sort_order, 0, GETDATE());
    RETURN;
END

---------------------------------------------------------
-- Insert_Q_StartTime
---------------------------------------------------------
IF @operation = 'Insert_Q_StartTime'
BEGIN
    UPDATE doctor_login SET q_start_before = @q_start_before WHERE doctor_id = @doctor_id;
    RETURN;
END

---------------------------------------------------------
-- fetchClinicGallery
---------------------------------------------------------
IF @operation = 'fetchClinicGallery'
BEGIN
    SELECT clinic_image_id, clinic_id, image_url, sort_order
    FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id AND active_status = 0
    ORDER BY sort_order;
    RETURN;
END

---------------------------------------------------------
-- deleteClinicGallery
---------------------------------------------------------
IF @operation = 'deleteClinicGallery'
BEGIN
    DELETE FROM dbo.clinic_images
    WHERE clinic_id = @clinic_id
      AND image_url IN (SELECT value FROM STRING_SPLIT(@image_url, ','));
    SELECT @@ROWCOUNT AS deleted_count, 'Images deleted' AS message;
    RETURN;
END

---------------------------------------------------------
-- AddClinic
---------------------------------------------------------
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

---------------------------------------------------------
-- GetDoctorClinics
---------------------------------------------------------
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

---------------------------------------------------------
-- UpdateClinic
---------------------------------------------------------
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

---------------------------------------------------------
-- DeleteClinic
---------------------------------------------------------
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
GO

-- =====================================================================
-- STEP 2 (data fix) - run SEPARATELY, after step 1.
-- Originally ALL doctor rows had is_verified = 0. Today doctors 31-49,
-- 51-57 and 59 are 1 (the 4-Nov backfill set them) and would be blocked.
-- See who is 1, then set the ones that should log in back to 0:
--
--   SELECT doctor_id, name, mobile, is_verified FROM dbo.doctor_login
--   WHERE is_verified = 1 AND active_status = 0;
--
-- Everyone (as originally):
--   UPDATE dbo.doctor_login SET is_verified = 0 WHERE active_status = 0;
-- Only some:
--   UPDATE dbo.doctor_login SET is_verified = 0 WHERE doctor_id IN (31, 49, 55, 59);
-- =====================================================================
