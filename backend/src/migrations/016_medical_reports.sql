-- =============================================================================
-- Migration 016: medical_reports
-- =============================================================================
-- AI summaries of uploaded lab/medical reports (routes/reports.js).
-- patient_id NULL = a doctor's unassigned report (inbox). user_type follows
-- patient_records: 2 = family member (patient_id is then a member_id).
-- input_tokens/output_tokens = Claude usage; NULL when the summary was reused
-- from an identical earlier upload (file_hash), i.e. no credits spent.
-- Rollback: 016_medical_reports_rollback.sql (see ROLLBACK_AI_REPORTS.md).
-- =============================================================================

IF OBJECT_ID('dbo.medical_reports') IS NULL
CREATE TABLE dbo.medical_reports (
    report_id        int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_medical_reports PRIMARY KEY,
    doctor_id        int NULL,
    patient_id       int NULL,
    user_type        int NULL,
    prescription_id  int NULL,
    uploaded_by_role tinyint NOT NULL,
    uploaded_by_id   int NOT NULL,
    file_names       nvarchar(max) NOT NULL,
    summary          nvarchar(max) NOT NULL,
    file_hash        char(64) NOT NULL,
    input_tokens     int NULL,
    output_tokens    int NULL,
    created_at       datetime NOT NULL CONSTRAINT DF_medical_reports_created_at DEFAULT (getdate())
);
GO

CREATE INDEX IX_medical_reports_doctor ON dbo.medical_reports (doctor_id, patient_id);
CREATE INDEX IX_medical_reports_patient ON dbo.medical_reports (patient_id, user_type);
CREATE INDEX IX_medical_reports_prescription ON dbo.medical_reports (prescription_id);
CREATE INDEX IX_medical_reports_hash ON dbo.medical_reports (file_hash);
CREATE INDEX IX_medical_reports_uploader ON dbo.medical_reports (uploaded_by_id, uploaded_by_role, created_at);
GO
