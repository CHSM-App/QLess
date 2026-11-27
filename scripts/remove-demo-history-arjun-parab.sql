-- Undo scripts/add-demo-history-arjun-parab.sql: removes the demo patient
-- (9878000001) with all visits, prescriptions, review and stock movements,
-- plus the demo stock purchases. The medicines stay in the library and the
-- clinic's list (they are useful real entries); stock goes back to zero.

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @patient INT = (SELECT patient_id FROM Patients WHERE mobile_no = '9878000001');

DELETE s FROM Clinic_Stock_Movement s
WHERE s.clinic_id = 'CL001'
  AND (s.note IN (N'Opening stock (demo)', N'Restock (demo)')
       OR s.presc_med_id IN (SELECT pm.presc_med_id FROM PrescriptionMedicine pm
                             JOIN patient_records r ON r.prescription_id = pm.prescription_id
                             WHERE r.patient_id = @patient));
DELETE FROM reviews WHERE patient_id = @patient;
DELETE pm FROM PrescriptionMedicine pm JOIN patient_records r ON r.prescription_id = pm.prescription_id
WHERE r.patient_id = @patient;
DELETE FROM patient_records WHERE patient_id = @patient;
DELETE FROM appointments WHERE patient_id = @patient;
DELETE FROM Patients WHERE patient_id = @patient;

COMMIT TRAN;
