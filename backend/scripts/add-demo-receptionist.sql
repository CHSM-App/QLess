-- Adds a demo Receptionist account for App Store / Play Store review,
-- attached to Dr. Manoj Swant's clinic (see add-manoj-swant-kudal.sql) so a
-- reviewer logging in as this receptionist sees a real clinic queue.
--
-- Mobile sits inside the receptionist demo range used by the OTP bypass
-- (see DEMO_RANGES in routes/login.js and isDemoNumber() in
-- frontend/lib/core/demo_accounts.dart): 9877000001-9877000030.
--
-- Login: 9877000001 + demo OTP 123456 — no SMS is sent for this number.
--
-- Run add-manoj-swant-kudal.sql FIRST — this script looks up his doctor_id
-- by mobile 9000000001 and fails loudly if that row doesn't exist yet.
--
-- Review before running. Safe to re-run: it checks for an existing row
-- with this mobile and rolls back instead of inserting a duplicate.

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @mobile       NVARCHAR(20) = '9877000001';
DECLARE @name         NVARCHAR(100) = 'Demo Receptionist';
DECLARE @doctor_mobile NVARCHAR(20) = '9000000001';
DECLARE @clinic_id    NVARCHAR(50) = 'CL060';
DECLARE @doctor_id    INT;

SELECT @doctor_id = doctor_id FROM doctor_login WHERE mobile = @doctor_mobile;

IF @doctor_id IS NULL
BEGIN
  RAISERROR('Dr. Manoj Swant (mobile 9000000001) not found — run add-manoj-swant-kudal.sql first', 16, 1);
  ROLLBACK TRAN;
  RETURN;
END

IF EXISTS (SELECT 1 FROM receptionist WHERE mobile_no = @mobile)
BEGIN
  RAISERROR('Mobile already exists in receptionist', 16, 1);
  ROLLBACK TRAN;
  RETURN;
END

INSERT INTO receptionist
  (name, mobile_no, email, Address, gender_id, active_status, token, img_url,
   clinic_id, created_at, role_id, doctor_id)
VALUES
  (@name, @mobile, NULL, NULL, NULL, 1, NULL, NULL,
   @clinic_id, GETDATE(), 3 /* ROLE.RECEPTIONIST, see routes/middleware/roles.js */, @doctor_id);

COMMIT TRAN;

SELECT recep_id, name, mobile_no, clinic_id, doctor_id FROM receptionist WHERE mobile_no = @mobile;
