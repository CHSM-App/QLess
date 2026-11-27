-- =============================================================================
-- Migration 012: refresh_tokens_id_sequence   (IMPROVEMENT_PLAN D7)
-- =============================================================================
-- RefreshTokens.id had no IDENTITY, so every login took MAX(id)+1 under a
-- table lock (UPDLOCK, HOLDLOCK). A sequence default numbers rows the same way
-- without the lock or rebuilding the table; the insert now omits id.
-- =============================================================================

DECLARE @start INT = (SELECT ISNULL(MAX(id), 0) + 1 FROM dbo.RefreshTokens);
DECLARE @ddl NVARCHAR(200) = CONCAT('CREATE SEQUENCE dbo.RefreshTokens_id AS INT START WITH ', @start, ' INCREMENT BY 1');
EXEC (@ddl);
GO

ALTER TABLE dbo.RefreshTokens
    ADD CONSTRAINT DF_RefreshTokens_id DEFAULT (NEXT VALUE FOR dbo.RefreshTokens_id) FOR id
GO
