-- =============================================================================
-- Rollback 007: refresh_token_hash
-- =============================================================================
-- A hash cannot be turned back into a token, so rolling back ends every
-- session: all users sign in again once. Only together with reverting
-- src/queries/refreshTokens.js.
-- =============================================================================

ALTER TABLE dbo.RefreshTokens ADD refresh_token NVARCHAR(MAX) NULL
GO

DELETE FROM dbo.RefreshTokens
GO

DROP INDEX IX_RefreshTokens_user_mobile ON dbo.RefreshTokens
GO

DROP INDEX UX_RefreshTokens_token_hash ON dbo.RefreshTokens
GO

ALTER TABLE dbo.RefreshTokens DROP COLUMN token_hash
GO

ALTER TABLE dbo.RefreshTokens ALTER COLUMN refresh_token NVARCHAR(MAX) NOT NULL
GO
