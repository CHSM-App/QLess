-- =============================================================================
-- Rollback 016: medical_reports — drops the table (and its indexes).
-- Back it up first if the data matters (ROLLBACK_AI_REPORTS.md, step 1).
-- =============================================================================

IF OBJECT_ID('dbo.medical_reports') IS NOT NULL
    DROP TABLE dbo.medical_reports;
GO
