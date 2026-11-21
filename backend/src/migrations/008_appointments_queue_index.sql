-- =============================================================================
-- Migration 008: appointments_queue_index   (IMPROVEMENT_PLAN D2)
-- =============================================================================
-- The live queue (next / skip / recall / position and proximity notifications)
-- filters appointments by queue_id + status; no index started with queue_id,
-- so each step scanned the doctor's whole day (or the table).
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_appointments_queue
    ON dbo.appointments (queue_id, status)
    INCLUDE (queue_number, booking_type, patient_id, user_type)
GO
