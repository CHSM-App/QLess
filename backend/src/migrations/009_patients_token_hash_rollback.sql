-- Rollback 009: patients_token_hash (only together with reverting
-- insertNotificationForToken to "WHERE token = @token").
DROP INDEX IX_Patients_token_hash ON dbo.Patients
GO

ALTER TABLE dbo.Patients DROP COLUMN token_hash
GO
