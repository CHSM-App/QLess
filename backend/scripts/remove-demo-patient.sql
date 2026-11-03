-- Rolls back add-demo-patient.sql: removes the patient with mobile
-- 9878000001. Run the SELECT first to see what will be deleted.

SET XACT_ABORT ON;

DECLARE @mobile NVARCHAR(20) = '9878000001';

DECLARE @patient_id INT = (SELECT patient_id FROM Patients WHERE mobile_no = @mobile);

-- Preview
SELECT 'Patients' AS tbl, patient_id, name, mobile_no FROM Patients WHERE patient_id = @patient_id;

IF @patient_id IS NULL
BEGIN
  RAISERROR('No patient with this mobile - nothing deleted', 16, 1);
  RETURN;
END

BEGIN TRAN;

DELETE FROM Patients WHERE patient_id = @patient_id;

COMMIT TRAN;
