-- =============================================================================
-- Migration 011: appointments_status_check   (IMPROVEMENT_PLAN D6)
-- =============================================================================
-- appointments.status is free text. These are the values the code writes or
-- reads; the collation is case-insensitive, so 'cancled' also admits
-- 'CancleD' — the app's "cancelled by doctor" (keep that spelling: the app
-- matches it). 'waiting' is read by older code and kept for safety.
-- Stops if any row holds another value, listing them, so nothing is rejected
-- later in the middle of an unrelated UPDATE. Map those rows first, then rerun.
-- =============================================================================

IF EXISTS (
    SELECT 1 FROM dbo.appointments
    WHERE status IS NOT NULL
      AND status NOT IN ('booked', 'waiting', 'in_progress', 'completed', 'skipped',
                         'cancelled', 'cancled', 'reschedule')
)
BEGIN
    DECLARE @bad NVARCHAR(4000) = (
        SELECT STRING_AGG(CONCAT(status, ' (', n, ')'), ', ')
        FROM (SELECT status, COUNT(*) n FROM dbo.appointments
              WHERE status IS NOT NULL
                AND status NOT IN ('booked', 'waiting', 'in_progress', 'completed', 'skipped',
                                   'cancelled', 'cancled', 'reschedule')
              GROUP BY status) x);
    DECLARE @msg NVARCHAR(4000) = CONCAT('011: unknown appointment status values: ', @bad);
    THROW 50011, @msg, 1;
END
GO

ALTER TABLE dbo.appointments WITH CHECK ADD CONSTRAINT CK_appointments_status
    CHECK (status IN ('booked', 'waiting', 'in_progress', 'completed', 'skipped',
                      'cancelled', 'cancled', 'reschedule'))
GO
