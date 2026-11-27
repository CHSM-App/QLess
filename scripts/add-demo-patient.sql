-- Adds a demo Patient account for App Store / Play Store review.
-- Mobile sits inside the patient demo range used by the OTP bypass
-- (see DEMO_RANGES in src/routes/auth.js and isDemoNumber() in
-- frontend/lib/core/demo_accounts.dart): 9878000001-9878000050.
--
-- Login: 9878000001 + demo OTP 123456 — no SMS is sent for this number.
--
-- Review before running. Safe to re-run: it checks for an existing row
-- with this mobile and rolls back instead of inserting a duplicate.

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @mobile NVARCHAR(20) = '9878000001';
DECLARE @name   NVARCHAR(100) = 'Demo Patient';

IF EXISTS (SELECT 1 FROM Patients WHERE mobile_no = @mobile)
BEGIN
  RAISERROR('Mobile already exists in Patients', 16, 1);
  ROLLBACK TRAN;
  RETURN;
END

INSERT INTO Patients
  (name, mobile_no, email, Address, gender_id, DOB, blood_group_id, weight,
   role_id, active_status, token, img_url)
VALUES
  (@name, @mobile, NULL, NULL, NULL, NULL, NULL, NULL,
   2 /* ROLE.PATIENT, see src/middleware/roles.js */, 1, NULL, NULL);

COMMIT TRAN;

SELECT patient_id, name, mobile_no FROM Patients WHERE mobile_no = @mobile;
