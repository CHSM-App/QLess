-- =============================================================================
-- Rollback 013: clinic_medicine_stock
-- =============================================================================
-- WARNING: all stock history, clinic medicine settings and the per-line
-- source / qty / price on prescriptions are DROPPED.
-- The 'Consumables' type is removed only if no medicine uses it.
-- =============================================================================

DROP TABLE IF EXISTS dbo.Clinic_Stock_Movement
GO

DROP TABLE IF EXISTS dbo.Clinic_Medicine
GO

ALTER TABLE dbo.PrescriptionMedicine DROP CONSTRAINT IF EXISTS CK_PrescriptionMedicine_source
GO
ALTER TABLE dbo.PrescriptionMedicine DROP CONSTRAINT IF EXISTS DF_PrescriptionMedicine_administered
GO
ALTER TABLE dbo.PrescriptionMedicine DROP COLUMN IF EXISTS source, administered_at_clinic, qty_given, unit_price
GO

DELETE t FROM dbo.Medicine_Type t
WHERE t.Medi_Type_Name = N'Consumables'
  AND NOT EXISTS (SELECT 1 FROM dbo.Medicine_Master m WHERE m.medicine_type_id = t.medicine_type_id)
GO
