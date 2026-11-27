-- =============================================================================
-- Migration 003: drop_sp_favorite_doctors
-- =============================================================================
-- The four favorite-doctor routes now run their SQL inline
-- (routes/patient/insert.js, users.js, index.js), translated branch by branch
-- from this procedure and checked against it on QLess_test_db.
-- Nothing calls it any more.
-- =============================================================================

DROP PROCEDURE IF EXISTS dbo.sp_favorite_doctors
GO
