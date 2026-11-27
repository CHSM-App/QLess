-- Rolls back add-manoj-swant-kudal.sql: removes the doctor with mobile
-- 9000000001 and clinic CL060 (only if CL060 belongs to that doctor).
-- Run the SELECTs first (below) to see what will be deleted.

SET XACT_ABORT ON;

DECLARE @mobile    NVARCHAR(20) = '9000000001';
DECLARE @clinic_id NVARCHAR(50) = 'CL060';

DECLARE @doctor_id INT = (SELECT doctor_id FROM doctor_login WHERE mobile = @mobile);

-- Preview
SELECT 'doctor_login' AS tbl, doctor_id, name, mobile, clinic_id FROM doctor_login WHERE doctor_id = @doctor_id;
SELECT 'clinics' AS tbl, clinic_id, clinic_name, doctor_id FROM clinics WHERE clinic_id = @clinic_id;

IF @doctor_id IS NULL OR @doctor_id = 1
BEGIN
  RAISERROR('No doctor with this mobile (or it is doctor_id 1) - nothing deleted', 16, 1);
  RETURN;
END

IF NOT EXISTS (SELECT 1 FROM clinics WHERE clinic_id = @clinic_id AND doctor_id = @doctor_id)
BEGIN
  RAISERROR('CL060 does not belong to this doctor - nothing deleted', 16, 1);
  RETURN;
END

BEGIN TRAN;

-- Rows the doctor may have created after login (safe if empty)
DELETE FROM doctor_time_slots
  WHERE availability_id IN (SELECT availability_id FROM doctor_availability WHERE doctor_id = @doctor_id);
DELETE FROM doctor_availability WHERE doctor_id = @doctor_id;
DELETE FROM doctor_leave WHERE doctor_id = @doctor_id;
DELETE FROM doctor_queue WHERE doctor_id = @doctor_id;

DELETE FROM clinics WHERE clinic_id = @clinic_id AND doctor_id = @doctor_id;
DELETE FROM doctor_login WHERE doctor_id = @doctor_id;

COMMIT TRAN;
