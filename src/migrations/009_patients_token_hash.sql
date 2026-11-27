-- =============================================================================
-- Migration 009: patients_token_hash   (IMPROVEMENT_PLAN D3)
-- =============================================================================
-- Every queue push writes an inbox row for the token's owner, found with
-- "WHERE token = @token" on an NVARCHAR(MAX) column that cannot be indexed:
-- one table scan per notified patient. A persisted hash of the token can be.
-- insertNotificationForToken (routes/doctor/insert/shared.js) looks up by
-- token_hash and still compares token, so a hash collision cannot mismatch.
-- =============================================================================

ALTER TABLE dbo.Patients
    ADD token_hash AS CONVERT(CHAR(64), HASHBYTES('SHA2_256', token), 2) PERSISTED
GO

CREATE NONCLUSTERED INDEX IX_Patients_token_hash
    ON dbo.Patients (token_hash)
GO
