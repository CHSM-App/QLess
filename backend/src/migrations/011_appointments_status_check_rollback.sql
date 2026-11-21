-- Rollback 011: appointments_status_check
ALTER TABLE dbo.appointments DROP CONSTRAINT CK_appointments_status
GO
