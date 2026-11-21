-- =============================================================================
-- Migration 010: notifications_once_index   (IMPROVEMENT_PLAN D5, redefined)
-- =============================================================================
-- Position/proximity pushes go out once per stage per appointment
-- (ref_id = '<appointment_id>:<stage>'). The "already sent?" lookup on
-- (patient_id, type, ref_id) had no index, and check-then-insert raced when two
-- queue moves landed together. The insert is now one atomic statement
-- (notifications INSERT_ONCE); this index serves its lookup.
-- Not UNIQUE on purpose: type 'queue' with ref_id = doctor_id repeats every
-- day (queue started / paused), so a unique key would drop real notifications.
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_notifications_patient_type_ref
    ON dbo.notifications (patient_id, type, ref_id)
GO
