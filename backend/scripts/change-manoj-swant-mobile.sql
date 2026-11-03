-- Changes Dr. Manoj Swant's login number from 9876000001 to 9000000001.
-- doctor_login.mobile is UNIQUE, so 9000000001 must not already exist
-- (run remove-manoj-swant-kudal.sql first if add-manoj-swant-kudal.sql was run).

SET XACT_ABORT ON;

DECLARE @old_mobile NVARCHAR(20) = '9876000001';
DECLARE @new_mobile NVARCHAR(20) = '9000000001';

-- Preview
SELECT doctor_id, name, mobile, clinic_id FROM doctor_login WHERE mobile IN (@old_mobile, @new_mobile);

IF NOT EXISTS (SELECT 1 FROM doctor_login WHERE mobile = @old_mobile)
BEGIN
  RAISERROR('Old mobile not found - nothing changed', 16, 1);
  RETURN;
END

IF EXISTS (SELECT 1 FROM doctor_login WHERE mobile = @new_mobile)
BEGIN
  RAISERROR('New mobile already exists in doctor_login - nothing changed', 16, 1);
  RETURN;
END

BEGIN TRAN;

UPDATE doctor_login SET mobile = @new_mobile WHERE mobile = @old_mobile;

-- Keep the clinic contact in sync if it held the old number
UPDATE clinics SET clinic_contact = @new_mobile
WHERE clinic_contact = @old_mobile
  AND doctor_id = (SELECT doctor_id FROM doctor_login WHERE mobile = @new_mobile);

COMMIT TRAN;

SELECT doctor_id, name, mobile, clinic_id FROM doctor_login WHERE mobile = @new_mobile;
