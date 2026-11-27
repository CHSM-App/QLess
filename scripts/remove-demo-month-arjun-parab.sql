-- Undo scripts/add-demo-month-arjun-parab.sql: removes the 40 demo patients
-- (9878000002..9878000041) with all visits, prescriptions, reviews and stock
-- movements, plus the demo month restock.

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @patients TABLE (patient_id INT PRIMARY KEY);
INSERT INTO @patients SELECT patient_id FROM Patients WHERE mobile_no BETWEEN '9878000002' AND '9878000041';

DELETE s FROM Clinic_Stock_Movement s
WHERE s.clinic_id = 'CL001'
  AND (s.note = N'Restock (demo month)'
       OR s.presc_med_id IN (SELECT pm.presc_med_id FROM PrescriptionMedicine pm
                             JOIN patient_records r ON r.prescription_id = pm.prescription_id
                             WHERE r.patient_id IN (SELECT patient_id FROM @patients)));
DELETE FROM reviews WHERE patient_id IN (SELECT patient_id FROM @patients);
DELETE pm FROM PrescriptionMedicine pm JOIN patient_records r ON r.prescription_id = pm.prescription_id
WHERE r.patient_id IN (SELECT patient_id FROM @patients);
DELETE FROM patient_records WHERE patient_id IN (SELECT patient_id FROM @patients);
DELETE FROM appointments WHERE patient_id IN (SELECT patient_id FROM @patients);
DELETE FROM Patients WHERE patient_id IN (SELECT patient_id FROM @patients);

COMMIT TRAN;
