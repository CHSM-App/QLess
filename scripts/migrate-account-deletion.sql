-- ============================================================================
-- Migration: Upgrade AccountDeletionRequests for OTP-verified deletion flow
--
-- SAFE TO RUN MULTIPLE TIMES — all changes are guarded by existence checks.
-- Run against the QLess database before deploying the new backend.
-- ============================================================================

-- ── 1. Create table fresh if it does not exist ───────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM sys.objects WHERE name = 'AccountDeletionRequests' AND type = 'U'
)
BEGIN
    CREATE TABLE AccountDeletionRequests (
        id              INT              NOT NULL IDENTITY(1,1),
        phone           NVARCHAR(15)     NOT NULL,
        role_id         INT              NOT NULL,   -- 1=Doctor, 2=Patient, 3=Receptionist
        reason          NVARCHAR(500)    NULL,
        status          NVARCHAR(20)     NOT NULL DEFAULT 'pending',
        otp_verified_at DATETIME2        NULL,
        scheduled_for   DATETIME2        NULL,
        completed_at    DATETIME2        NULL,
        created_at      DATETIME2        NOT NULL DEFAULT GETUTCDATE(),

        CONSTRAINT PK_AccountDeletionRequests PRIMARY KEY (id),
        CONSTRAINT CK_ADR_status  CHECK (status IN ('pending', 'cancelled', 'completed')),
        CONSTRAINT CK_ADR_role_id CHECK (role_id IN (1, 2, 3))
    )

    CREATE UNIQUE INDEX UX_ADR_phone_role_pending
        ON AccountDeletionRequests (phone, role_id)
        WHERE status = 'pending'

    CREATE INDEX IX_ADR_scheduled
        ON AccountDeletionRequests (status, scheduled_for)

    PRINT 'AccountDeletionRequests created from scratch.'
END
GO

-- ── 2. Add missing columns to existing table ─────────────────────────────────
-- Each column is added in its own batch so DDL is committed before the next
-- check runs. This avoids "column not found" parse errors.

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'status'
)
BEGIN
    ALTER TABLE AccountDeletionRequests
        ADD status NVARCHAR(20) NOT NULL DEFAULT 'pending'
    ALTER TABLE AccountDeletionRequests
        ADD CONSTRAINT CK_ADR_status CHECK (status IN ('pending', 'cancelled', 'completed'))
    PRINT 'Added column: status'
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'otp_verified_at'
)
BEGIN
    ALTER TABLE AccountDeletionRequests ADD otp_verified_at DATETIME2 NULL
    PRINT 'Added column: otp_verified_at'
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'scheduled_for'
)
BEGIN
    ALTER TABLE AccountDeletionRequests ADD scheduled_for DATETIME2 NULL
    PRINT 'Added column: scheduled_for'
END
GO

-- Backfill scheduled_for for any pre-existing rows (runs after the column exists)
IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'scheduled_for'
)
BEGIN
    IF EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'created_at'
    )
        EXEC sp_executesql N'
            UPDATE AccountDeletionRequests
            SET scheduled_for = DATEADD(DAY, 30, created_at)
            WHERE scheduled_for IS NULL'
    ELSE
        EXEC sp_executesql N'
            UPDATE AccountDeletionRequests
            SET scheduled_for = DATEADD(DAY, 30, GETUTCDATE())
            WHERE scheduled_for IS NULL'
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'completed_at'
)
BEGIN
    ALTER TABLE AccountDeletionRequests ADD completed_at DATETIME2 NULL
    PRINT 'Added column: completed_at'
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'created_at'
)
BEGIN
    ALTER TABLE AccountDeletionRequests
        ADD created_at DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    PRINT 'Added column: created_at'
END
GO

-- ── 3. Add missing indexes ────────────────────────────────────────────────────

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'UX_ADR_phone_role_pending'
)
BEGIN
    CREATE UNIQUE INDEX UX_ADR_phone_role_pending
        ON AccountDeletionRequests (phone, role_id)
        WHERE status = 'pending'
    PRINT 'Added index: UX_ADR_phone_role_pending'
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('AccountDeletionRequests') AND name = 'IX_ADR_scheduled'
)
BEGIN
    CREATE INDEX IX_ADR_scheduled
        ON AccountDeletionRequests (status, scheduled_for)
    PRINT 'Added index: IX_ADR_scheduled'
END
GO

-- ── 4. Verify final schema ────────────────────────────────────────────────────
SELECT
    c.name      AS column_name,
    t.name      AS data_type,
    c.max_length,
    c.is_nullable,
    c.is_identity,
    c.column_id
FROM sys.columns c
JOIN sys.types   t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('AccountDeletionRequests')
ORDER BY c.column_id
GO
