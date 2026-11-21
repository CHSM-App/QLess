-- =============================================================================
-- Rollback 005: drop_sp_family_members
-- =============================================================================
-- Recreates sp_family_members exactly as in 000_baseline.sql. Only useful
-- together with reverting the inline-SQL routes.
-- =============================================================================

CREATE OR ALTER PROCEDURE [dbo].[sp_family_members]
(
    @operation NVARCHAR(20),

    @member_id INT = NULL,
    @family_id INT = NULL,
    @name NVARCHAR(100) = NULL,
    @Gender_id INT = NULL,
    @relation_id INT = NULL,
    @DOB SMALLDATETIME = NULL,
    @mobile_no NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

---------------------------------------------------------
-- INSERT MEMBER
---------------------------------------------------------
IF @operation = 'Insert'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.family_members
        (
            family_id,
            name,
            Gender_id,
            relation_id,
            DOB,
            mobile_no
        )
        VALUES
        (
            @family_id,
            @name,
            @Gender_id,
            @relation_id,
            @DOB,
            @mobile_no
        );

        SET @member_id = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @member_id AS member_id;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT 
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;
    END CATCH

RETURN;
END

---------------------------------------------------------
-- UPDATE MEMBER
---------------------------------------------------------
IF @operation = 'Update'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.family_members
        SET
            family_id = @family_id,
            name = @name,
            Gender_id = @Gender_id,
            relation_id = @relation_id,
            DOB = @DOB,
            mobile_no = @mobile_no
        WHERE member_id = @member_id;

        COMMIT TRANSACTION;

        SELECT @member_id AS member_id;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT 
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;
    END CATCH

RETURN;
END

---------------------------------------------------------
-- FETCH SINGLE MEMBER
---------------------------------------------------------
IF @operation = 'FetchMember'
BEGIN
    SELECT *
    FROM dbo.family_members
    WHERE member_id = @member_id;

RETURN;
END

---------------------------------------------------------
-- FETCH ALL MEMBERS BY FAMILY
---------------------------------------------------------
IF @operation = 'AllFamilyMembers'
BEGIN
 SELECT 
    fm.member_id,
    fm.family_id,
    fm.name,
    fm.Gender_id,
    g.Gender,          -- ✅ ADD THIS
    fm.relation_id,
    r.relation, -- ✅ ADD THIS
    fm.DOB,
    fm.mobile_no
FROM dbo.family_members fm
LEFT JOIN Gender g ON fm.Gender_id = g.gender_id
LEFT JOIN Relations r ON fm.relation_id = r.relation_id
    WHERE family_id = @family_id;
END
IF @operation = 'DeleteMember'
BEGIN
    BEGIN TRY
        DELETE FROM dbo.family_members
        WHERE member_id = @member_id;

        SELECT 1 AS success, 'Member deleted successfully' AS message;
    END TRY
    BEGIN CATCH
        SELECT 0 AS success, 
               'Member is used in other records, cannot delete.' AS message;
    END CATCH
END

END
GO
