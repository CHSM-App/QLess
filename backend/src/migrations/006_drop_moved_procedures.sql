-- =============================================================================
-- Migration 006: drop_moved_procedures
-- =============================================================================
-- The last 12 stored procedures now live in src/queries/*.js (one SQL batch per
-- operation, run by db.request().run() in src/db.js). Every operation the app
-- calls was compared against its procedure on QLess_test_db (results + all
-- table contents) before this drop. Nothing calls these any more.
-- 
-- Each is also dropped by its bare name: an earlier baseline created
-- sp_notification and sp_otp without a schema, so on a database whose login
-- has a default schema other than dbo they landed in that schema.
-- =============================================================================

DROP PROCEDURE IF EXISTS dbo.sp_appointment   -- → src/queries/appointments.js
GO
DROP PROCEDURE IF EXISTS sp_appointment
GO
DROP PROCEDURE IF EXISTS dbo.sp_doctor_login   -- → src/queries/doctors.js
GO
DROP PROCEDURE IF EXISTS sp_doctor_login
GO
DROP PROCEDURE IF EXISTS dbo.sp_patients   -- → src/queries/patients.js
GO
DROP PROCEDURE IF EXISTS sp_patients
GO
DROP PROCEDURE IF EXISTS dbo.sp_receptionist   -- → src/queries/receptionists.js
GO
DROP PROCEDURE IF EXISTS sp_receptionist
GO
DROP PROCEDURE IF EXISTS dbo.ManageRefreshToken   -- → src/queries/refreshTokens.js
GO
DROP PROCEDURE IF EXISTS ManageRefreshToken
GO
DROP PROCEDURE IF EXISTS dbo.sp_otp   -- → src/queries/otp.js
GO
DROP PROCEDURE IF EXISTS sp_otp
GO
DROP PROCEDURE IF EXISTS dbo.sp_doctor_schedule   -- → src/queries/doctorSchedule.js
GO
DROP PROCEDURE IF EXISTS sp_doctor_schedule
GO
DROP PROCEDURE IF EXISTS dbo.sp_slot_today_count   -- → src/queries/slotTodayCount.js
GO
DROP PROCEDURE IF EXISTS sp_slot_today_count
GO
DROP PROCEDURE IF EXISTS dbo.sp_doctor_leave   -- → src/queries/doctorLeave.js
GO
DROP PROCEDURE IF EXISTS sp_doctor_leave
GO
DROP PROCEDURE IF EXISTS dbo.sp_notification   -- → src/queries/notifications.js
GO
DROP PROCEDURE IF EXISTS sp_notification
GO
DROP PROCEDURE IF EXISTS dbo.sp_prescription   -- → src/queries/prescriptions.js
GO
DROP PROCEDURE IF EXISTS sp_prescription
GO
DROP PROCEDURE IF EXISTS dbo.sp_Medicine_Master   -- → src/queries/medicines.js
GO
DROP PROCEDURE IF EXISTS sp_Medicine_Master
GO
