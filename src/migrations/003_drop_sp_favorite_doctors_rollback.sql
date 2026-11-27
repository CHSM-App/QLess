-- =============================================================================
-- Rollback 003: drop_sp_favorite_doctors
-- =============================================================================
-- Recreates sp_favorite_doctors exactly as in 000_baseline.sql. Only useful
-- together with reverting the inline-SQL routes.
-- =============================================================================

CREATE OR ALTER PROCEDURE [dbo].[sp_favorite_doctors]
(
    @operation NVARCHAR(10),
    @patient_id INT,
    @doctor_id INT = NULL,
	 @clinic_id  NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ✅ Insert favorite (avoid duplicate)
    --IF @operation = 'Insert'
    --BEGIN
    --    IF NOT EXISTS (
    --        SELECT 1 FROM favorite_doctors 
    --        WHERE patient_id = @patient_id 
    --          AND doctor_id = @doctor_id
    --    )
    --    BEGIN
    --        INSERT INTO favorite_doctors (patient_id, doctor_id, is_favorite, created_at)
    --        VALUES (@patient_id, @doctor_id, 1, GETDATE());

    --        SELECT 1 AS success, SCOPE_IDENTITY() AS favorite_id, 'Added successfully' AS message;
    --    END
    --    ELSE
    --    BEGIN
    --        SELECT 0 AS success, 'Already added to favorites' AS message;
    --    END
    --END
	 IF @operation = 'Insert'
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM favorite_doctors 
            WHERE patient_id = @patient_id 
              AND doctor_id  = @doctor_id
			  AND clinic_id=@clinic_id
        )
        BEGIN
            INSERT INTO favorite_doctors (patient_id, doctor_id, clinic_id, is_favorite, created_at)
            VALUES (@patient_id, @doctor_id, @clinic_id, 1, GETDATE());

            SELECT 1 AS success, SCOPE_IDENTITY() AS favorite_id, 'Added successfully' AS message;
        END
        ELSE
        BEGIN
            ---- Update clinic_id if it was missing
            --UPDATE favorite_doctors
            --SET clinic_id = COALESCE(@clinic_id, clinic_id)
            --WHERE patient_id = @patient_id AND doctor_id = @doctor_id;

            SELECT 0 AS success, 'Already added to favorites' AS message;
        END
    END

    -- ✅ Delete favorite
    ELSE IF @operation = 'Delete'
    BEGIN
        DELETE FROM favorite_doctors
        WHERE patient_id = @patient_id
          AND doctor_id = @doctor_id
		  AND clinic_id=@clinic_id;


        SELECT 1 AS success, 'Deleted successfully' AS message;
    END

    -- ✅ Fetch (2 cases handled)
    ELSE IF @operation = 'Fetch'
    BEGIN
        -- 👉 Case 1: Check single doctor (for heart icon)
        IF @doctor_id IS NOT NULL
        BEGIN
            SELECT 
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM favorite_doctors 
                        WHERE patient_id = @patient_id 
                          AND doctor_id = @doctor_id
						  AND clinic_id=@clinic_id
                          AND is_favorite = 1
                    )
                    THEN 1 ELSE 0 
                END AS is_favorite;
        END
        ELSE
        BEGIN
            -- 👉 Case 2: Get all favorite doctors of patient
            SELECT *
            FROM favorite_doctors
            WHERE patient_id = @patient_id
              AND is_favorite = 1
            ORDER BY created_at DESC;
        END
    END
END
GO
