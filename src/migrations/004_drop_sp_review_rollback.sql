-- =============================================================================
-- Rollback 004: drop_sp_review
-- =============================================================================
-- Recreates sp_review exactly as in 000_baseline.sql. Only useful together
-- with reverting the inline-SQL routes.
-- =============================================================================

CREATE OR ALTER PROCEDURE [dbo].[sp_review]
(
    @operation NVARCHAR(10),
    @appointment_id INT = NULL,
    @doctor_id INT = NULL,
    @patient_id INT = NULL,
    -- Half-star precision: 0.5, 1.0, 1.5, ... 5.0. INT would truncate
    -- 3.5 → 3 silently at the parameter boundary, before INSERT even
    -- reaches the DECIMAL column.
    @rating DECIMAL(2,1) = NULL,
    @comment NVARCHAR(500) = NULL,
    @reviewed_by_user_id INT = NULL,
	  @clinic_id           NVARCHAR(50)  = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ✅ Insert review (appointment-based, avoid duplicate)
  IF @operation = 'Insert'
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM appointments
            WHERE appointment_id = @appointment_id
              AND doctor_id      = @doctor_id
              AND patient_id     = @patient_id
              AND status         = 'completed'
        )
        BEGIN
            SELECT 0 AS success, 'Appointment not completed or invalid' AS message;
            RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM reviews
            WHERE appointment_id = @appointment_id
        )
        BEGIN
            SELECT 0 AS success, 'Review already submitted' AS message;
            RETURN;
        END

        INSERT INTO reviews (appointment_id, doctor_id, patient_id, rating, comment, created_at, reviewed_by_user_id, clinic_id)
        VALUES (@appointment_id, @doctor_id, @patient_id, @rating, @comment, GETDATE(), @reviewed_by_user_id, @clinic_id);

        UPDATE appointments
        SET is_reviewed = 1
        WHERE appointment_id = @appointment_id;

        SELECT 1 AS success, SCOPE_IDENTITY() AS review_id, 'Review added' AS message;
    END

    -- ✅ Delete review (by appointment + patient)
    ELSE IF @operation = 'Delete'
    BEGIN
        DELETE FROM reviews
        WHERE appointment_id = @appointment_id
          AND patient_id = @patient_id;

        SELECT 1 AS success, 'Review deleted' AS message;
    END

    -- ✅ Fetch reviews
    ELSE IF @operation = 'Fetch'
    BEGIN
        -- Case 1: Single appointment review
        IF @appointment_id IS NOT NULL
        BEGIN
            SELECT * FROM reviews
            WHERE appointment_id = @appointment_id;
        END
        ELSE
        BEGIN
            -- Case 2: All reviews of a doctor
            SELECT
                r.review_id,
                r.appointment_id,
                r.doctor_id,
                r.patient_id,

                -- whose account submitted review
                p.name AS reviewed_by_name,

                -- actual appointment for whom
                CASE
                   WHEN r.patient_id = r.reviewed_by_user_id
                        THEN p.name
                   ELSE fm.name
                END AS patient_name,

                r.rating,
                r.comment,
                r.created_at

            FROM reviews r

            LEFT JOIN Patients p
               ON p.patient_id = r.reviewed_by_user_id

            LEFT JOIN family_members fm
               ON fm.member_id = r.patient_id


			   WHERE r.doctor_id = @doctor_id
  AND (@clinic_id IS NULL OR r.clinic_id = @clinic_id OR r.clinic_id IS NULL)
ORDER BY r.created_at DESC;


            --WHERE r.doctor_id = @doctor_id
            --ORDER BY r.created_at DESC;
        END
    END
END
GO
