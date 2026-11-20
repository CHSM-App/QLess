-- =============================================================================
-- Rollback 001: medicine_brand_components
-- =============================================================================
-- Puts sp_Medicine_Master and Medicine_Master back as they were before 001
-- (procedure body taken from 000_baseline.sql).
--
-- WARNING: brand_name / strength / components data is DROPPED. Re-adding the
-- old (name, type) unique key FAILS if the same medicine now exists under two
-- brands or strengths. Remove those duplicate rows first if you hit that.
-- =============================================================================

CREATE OR ALTER PROCEDURE [dbo].[sp_Medicine_Master]
    @operation        NVARCHAR(20)  = NULL,
    @medicine_id      INT           = 0,
    @doctor_id        INT           = 0,
    @medicine_name    NVARCHAR(100) = NULL,
    @medicine_type_id INT           = NULL,
    @search_query     NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ─────────────────────────────────────────────────────────
    -- INSERT: global library + per-doctor link
    -- ─────────────────────────────────────────────────────────
    IF @operation = 'Insert'
    BEGIN
        DECLARE @medId INT;

        -- 1. Medicine_Master madhe (name+type) ahe ka check
        SELECT @medId = medicine_id
        FROM dbo.Medicine_Master
        WHERE medicine_name    = @medicine_name
          AND medicine_type_id = @medicine_type_id;

        -- 2. Naselich tar global library madhe insert
        IF @medId IS NULL
        BEGIN
            INSERT INTO dbo.Medicine_Master (medicine_name, medicine_type_id)
            VALUES (@medicine_name, @medicine_type_id);
            SET @medId = SCOPE_IDENTITY();
        END

        -- 3. Already active link asla → duplicate prevent
        IF EXISTS (
            SELECT 1 FROM dbo.Doctor_Medicine
            WHERE doctor_id   = @doctor_id
              AND medicine_id = @medId
              AND is_active   = 1
        )
        BEGIN
            SELECT 'Medicine already in your list.' AS Message;
            RETURN;
        END

        -- 4. Soft-deleted link asla → reactivate
        IF EXISTS (
            SELECT 1 FROM dbo.Doctor_Medicine
            WHERE doctor_id   = @doctor_id
              AND medicine_id = @medId
              AND is_active   = 0
        )
        BEGIN
            UPDATE dbo.Doctor_Medicine
            SET    is_active = 1
            WHERE  doctor_id   = @doctor_id
              AND  medicine_id = @medId;

            SELECT 'Medicine reactivated.' AS Message;
            RETURN;
        END

        -- 5. Navin link insert
        INSERT INTO dbo.Doctor_Medicine (doctor_id, medicine_id, is_active)
        VALUES (@doctor_id, @medId, 1);

        SELECT 'Medicine added successfully.' AS Message;
    END

    -- ─────────────────────────────────────────────────────────
    -- GET MEDICINE TYPES
    -- ─────────────────────────────────────────────────────────
    IF @operation = 'getMedicineTypes'
    BEGIN
        SELECT * FROM dbo.Medicine_Type;
    END

    -- ─────────────────────────────────────────────────────────
    -- FETCH ALL MEDICINES (per doctor list)
    -- ─────────────────────────────────────────────────────────
    IF @operation = 'fetchAllMedicines'
    BEGIN
        SELECT
            m.medicine_id,
            dm.doctor_id,
            m.medicine_name,
            m.medicine_type_id,
            t.Medi_Type_Name
        FROM   dbo.Doctor_Medicine dm
        INNER JOIN dbo.Medicine_Master m ON dm.medicine_id    = m.medicine_id
        INNER JOIN dbo.Medicine_Type   t ON m.medicine_type_id = t.medicine_type_id
        WHERE  dm.doctor_id = @doctor_id
          AND  dm.is_active = 1
        ORDER BY m.medicine_name;
    END

    -- ─────────────────────────────────────────────────────────
    -- GET SUGGESTIONS (NEW — global library madhun typing veli)
    -- ─────────────────────────────────────────────────────────
    IF @operation = 'getSuggestions'
    BEGIN
        SELECT TOP 20
            m.medicine_id,
            m.medicine_name,
            m.medicine_type_id,
            t.Medi_Type_Name
        FROM   dbo.Medicine_Master m
        INNER JOIN dbo.Medicine_Type t ON m.medicine_type_id = t.medicine_type_id
        WHERE  m.medicine_name LIKE @search_query + '%'
        ORDER BY m.medicine_name;
    END

    -- ─────────────────────────────────────────────────────────
    -- DELETE (per-doctor soft delete; library la touch nahi)
    -- ─────────────────────────────────────────────────────────
    IF @operation = 'Delete'
    BEGIN
        UPDATE dbo.Doctor_Medicine
        SET    is_active = 0
        WHERE  medicine_id = @medicine_id
          AND  doctor_id   = @doctor_id
          AND  is_active   = 1;

        IF @@ROWCOUNT > 0
            SELECT 'Medicine removed from your list.' AS Message;
        ELSE
            SELECT 'No medicine found to delete.' AS Message;
    END
END
GO

IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_Medicine_Name_Type_Brand_Strength')
    ALTER TABLE dbo.Medicine_Master DROP CONSTRAINT UQ_Medicine_Name_Type_Brand_Strength
GO

IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_Medicine_Name_Type')
    ALTER TABLE dbo.Medicine_Master ADD CONSTRAINT UQ_Medicine_Name_Type
        UNIQUE (medicine_name, medicine_type_id)
GO

IF COL_LENGTH('dbo.Medicine_Master', 'brand_name') IS NOT NULL
    ALTER TABLE dbo.Medicine_Master DROP COLUMN brand_name, strength, components
GO
