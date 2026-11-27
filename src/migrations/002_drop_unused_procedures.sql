-- =============================================================================
-- Migration 002: drop_unused_procedures
-- =============================================================================
-- Nothing in the backend calls these (checked: no execute('<name>') anywhere in
-- routes/). sp_Medicin_Type is a misspelt leftover; sp_Medicine_Master's
-- 'getMedicineTypes' operation is what the app actually uses.
--
-- Medicine_Master_Backup is deliberately NOT dropped here: it is a table that
-- may hold data. Drop it in its own migration once someone confirms it is junk.
-- =============================================================================

DROP PROCEDURE IF EXISTS dbo.sp_doc
GO
DROP PROCEDURE IF EXISTS dbo.sp_users_manage
GO
DROP PROCEDURE IF EXISTS dbo.sp_Medicin_Type
GO
