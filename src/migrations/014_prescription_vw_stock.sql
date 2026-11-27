-- =============================================================================
-- Migration 014: prescription_vw_stock
-- =============================================================================
-- Adds the clinic-stock columns from 013 (source, administered_at_clinic,
-- qty_given, unit_price) to prescription_vw, so PrescriptionDetail and
-- AppointmentWisePrescription (SELECT *) return them for the print and
-- patient screens. Everything else is the baseline view unchanged.
-- =============================================================================

CREATE OR ALTER VIEW [dbo].[prescription_vw]
AS
SELECT d.name AS doctor_name, d.qualification, d.experience, d.specialization, p.doctor_id, p.patient_id, CASE WHEN p.user_type = 1 THEN 'Self' WHEN p.user_type = 2 THEN 'Family' END AS user_type_name,
                  CASE WHEN p.user_type = 1 THEN pt.name WHEN p.user_type = 2 THEN fm.name END AS patient_name, p.prescription_id, p.prescription_date, p.symptoms, p.diagnosis, p.clinical_notes, p.follow_up_date, p.advice, p.created_at,
                  pm.presc_med_id, pm.medicine_id, mm.medicine_name, mm.medicine_type_id, mt.Medi_Type_Name, pm.frequency, pm.duration, pm.timing, pm.tablet_dosage, pm.syrup_dosage_ml, pm.inj_dosage, pm.inj_route, pm.drops_count,
                  pm.drops_application, pm.lotion_apply_area, pm.spray_puffs, pm.spray_usage, pm.lotion_usage, c.clinic_name, c.clinic_address, c.clinic_contact, p.user_type, p.appointment_id, pm.powder_dosage, pm.powder_form, pm.inhaler_puffs,
                  pm.inhaler_type, pm.inhaler_technique, pm.inhaler_usage, p.investigation,
                  pm.source, pm.administered_at_clinic, pm.qty_given, pm.unit_price
FROM     dbo.patient_records AS p INNER JOIN
                  dbo.appointments AS ap ON ap.appointment_id = p.appointment_id INNER JOIN
                  dbo.doctor_login AS d ON d.doctor_id = p.doctor_id LEFT OUTER JOIN
                  dbo.Patients AS pt ON p.patient_id = pt.patient_id AND p.user_type = 1 LEFT OUTER JOIN
                  dbo.family_members AS fm ON p.patient_id = fm.member_id AND p.user_type = 2 LEFT OUTER JOIN
                  dbo.PrescriptionMedicine AS pm ON p.prescription_id = pm.prescription_id LEFT OUTER JOIN
                  dbo.Medicine_Master AS mm ON mm.medicine_id = pm.medicine_id LEFT OUTER JOIN
                  dbo.Medicine_Type AS mt ON mm.medicine_type_id = mt.medicine_type_id INNER JOIN
                  dbo.clinics AS c ON c.clinic_id = ap.clinic_id
GO
