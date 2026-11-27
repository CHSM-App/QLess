-- Rollback 012: refresh_tokens_id_sequence (only together with reverting the
-- insert batch in src/queries/refreshTokens.js to MAX(id)+1).
ALTER TABLE dbo.RefreshTokens DROP CONSTRAINT DF_RefreshTokens_id
GO

DROP SEQUENCE dbo.RefreshTokens_id
GO
