-- Adds Dr. Manoj Swant as a separate doctor login (mobile 9000000001) with a
-- clinic in Kudal. Copies role/gender/timing defaults from the existing
-- Dr. Manoj (doctor_id = 1) so the new row behaves the same way.
-- doctor_login.mobile is UNIQUE, so this must be a new row, not a second
-- number on doctor_id = 1.
--
-- Review before running. Set @clinic_name / @address / @fee as needed.
-- Login: 9000000001 + demo OTP 123456 (see DEMO_RANGES in src/routes/auth.js).

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @mobile      NVARCHAR(20) = '9000000001';
DECLARE @clinic_id   NVARCHAR(50) = 'CL060';
DECLARE @clinic_name NVARCHAR(50) = 'Dr. Manoj Swant Clinic';
DECLARE @address     NVARCHAR(50) = 'Kudal, Sindhudurg';
DECLARE @fee         DECIMAL(10,2) = 300;

IF EXISTS (SELECT 1 FROM clinics WHERE clinic_id = @clinic_id)
BEGIN
  RAISERROR('clinic_id already exists in clinics', 16, 1);
  ROLLBACK TRAN;
  RETURN;
END

IF EXISTS (SELECT 1 FROM doctor_login WHERE mobile = @mobile)
BEGIN
  RAISERROR('Mobile already exists in doctor_login', 16, 1);
  ROLLBACK TRAN;
  RETURN;
END

INSERT INTO doctor_login
  (name, email, mobile, qualification, license_no, image, experience, specialization,
   created_at, role_id, active_status, is_verified, clinic_id, gender_id,
   q_start_before, avg_consultation_time)
SELECT
  'Dr. Manoj Swant', email, @mobile, qualification, license_no, image, experience, specialization,
  GETDATE(), role_id, 1, 1, @clinic_id, gender_id,
  q_start_before, avg_consultation_time
FROM doctor_login
WHERE doctor_id = 1;

DECLARE @new_doctor_id INT = SCOPE_IDENTITY();

INSERT INTO clinics
  (clinic_id, clinic_name, clinic_address, latitude, longitude, consultation_fee,
   created_at, clinic_contact, active_status, is_verified, doctor_id)
VALUES
  (@clinic_id, @clinic_name, @address, 16.0136000, 73.6853000, @fee,
   GETDATE(), @mobile, 1, 1, @new_doctor_id);

COMMIT TRAN;

SELECT doctor_id, name, mobile, clinic_id FROM doctor_login WHERE mobile = @mobile;
