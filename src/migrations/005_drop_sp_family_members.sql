-- =============================================================================
-- Migration 005: drop_sp_family_members
-- =============================================================================
-- Insert/update now live in src/familyMembers.js (shared by the patient app and
-- receptionist walk-in); list and delete are inline in routes/patient/users.js
-- and index.js. All checked against this procedure on QLess_test_db.
-- Nothing calls it any more.
-- =============================================================================

DROP PROCEDURE IF EXISTS dbo.sp_family_members
GO
