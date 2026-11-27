-- Rolls back add-demo-receptionist.sql: removes the receptionist with
-- mobile 9877000001. Run the SELECT first to see what will be deleted.

SET XACT_ABORT ON;

DECLARE @mobile NVARCHAR(20) = '9877000001';

DECLARE @recep_id INT = (SELECT recep_id FROM receptionist WHERE mobile_no = @mobile);

-- Preview
SELECT 'receptionist' AS tbl, recep_id, name, mobile_no, clinic_id, doctor_id
  FROM receptionist WHERE recep_id = @recep_id;

IF @recep_id IS NULL
BEGIN
  RAISERROR('No receptionist with this mobile - nothing deleted', 16, 1);
  RETURN;
END

BEGIN TRAN;

DELETE FROM receptionist WHERE recep_id = @recep_id;

COMMIT TRAN;
