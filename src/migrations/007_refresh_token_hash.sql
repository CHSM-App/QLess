-- =============================================================================
-- Migration 007: refresh_token_hash   (IMPROVEMENT_PLAN S4 + D1)
-- =============================================================================
-- Refresh tokens were stored in plain text (a DB leak = every session) in an
-- NVARCHAR(MAX) column that cannot be indexed (every refresh scanned the table).
-- Now only SHA-256(token) is kept, in an indexed CHAR(64). Existing tokens are
-- hashed in place, so nobody is signed out. SQL computes the hash both when
-- storing and when checking (src/queries/refreshTokens.js), from the same
-- NVARCHAR value, so the bytes always match.
-- =============================================================================

ALTER TABLE dbo.RefreshTokens ADD token_hash CHAR(64) NULL
GO

UPDATE dbo.RefreshTokens
SET token_hash = CONVERT(CHAR(64), HASHBYTES('SHA2_256', refresh_token), 2)
WHERE token_hash IS NULL
GO

CREATE UNIQUE NONCLUSTERED INDEX UX_RefreshTokens_token_hash
    ON dbo.RefreshTokens (token_hash) WHERE token_hash IS NOT NULL
GO

CREATE NONCLUSTERED INDEX IX_RefreshTokens_user_mobile
    ON dbo.RefreshTokens (user_mobile) INCLUDE (revoked)
GO

ALTER TABLE dbo.RefreshTokens DROP COLUMN refresh_token
GO
