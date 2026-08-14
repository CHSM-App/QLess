/*
  QLess — RefreshTokens role migration
  ---------------------------------------------------------------------------
  WHY:
  The 'insert' branch looked the role id up in doctor_login_vw / patient_login_vw
  / receptionist_vw by mobile. When that lookup found nothing — a receptionist
  whose view row carries no role_id, or a mobile stored in a different format —
  @role_id stayed NULL and the session row was written with role_id = NULL.

  /Createlogin survived that (it had its own fallback), but /refreshAccessToken
  reads the role straight off the row: it answered the app with roleId null, the
  app stored 0, and ~15 minutes after login every `roleId == 3` receptionist
  check turned false — the receptionist's screen became the doctor's, and the
  next app launch saw roleId 0 and wiped the session back to the login screen.

  FIX: the role name now maps directly to its id. The API resolves which role
  the account actually holds (see resolveAccountRole in routes/login.js) and
  passes the verified name here, so this procedure no longer depends on view
  contents or on how a mobile number happens to be formatted.

  ALSO: the id is assigned under UPDLOCK/HOLDLOCK. MAX(id)+1 read outside a lock
  hands the same id to two simultaneous logins and one of them dies on the
  primary key.

  Run against the database in backend/.env → DB_NAME.
*/

USE [QLess];
GO

-- 1) Column (already present on QLess; guarded so the script is re-runnable) --
IF COL_LENGTH('dbo.RefreshTokens', 'role_id') IS NULL
BEGIN
    ALTER TABLE dbo.RefreshTokens ADD role_id TINYINT NULL;
END
GO

-- 2) Sessions with no role cannot be refreshed correctly and cannot be
--    back-filled reliably. Dropping them costs each signed-in user one
--    re-login, which beats guessing a role and mis-typing their session.
DELETE FROM dbo.RefreshTokens WHERE role_id IS NULL;
GO

-- 3) Procedure ---------------------------------------------------------------
ALTER PROCEDURE [dbo].[ManageRefreshToken]
    @operation       NVARCHAR(20),       -- 'insert' | 'get' | 'revoke' | 'AutoTask'

    -- Insert fields
    @user_mobile     NVARCHAR(50) = NULL,
    @refresh_token   NVARCHAR(MAX) = NULL,
    @device_info     NVARCHAR(500) = NULL,
    @ip_address      NVARCHAR(100) = NULL,
    @expires_at      DATETIME2 = NULL,
    @role            NVARCHAR(20) = NULL -- 'doctor' | 'patient' | 'receptionist'
AS
BEGIN
    SET NOCOUNT ON;

    -- Insert Operation --------------------------------------------
    IF @operation = 'insert'
    BEGIN
        DECLARE @role_id TINYINT =
            CASE LOWER(LTRIM(RTRIM(ISNULL(@role, ''))))
                WHEN 'doctor'       THEN 1
                WHEN 'patient'      THEN 2
                WHEN 'receptionist' THEN 3
            END;

        -- Refuse to create a session whose role we cannot name. A NULL role_id
        -- here is exactly what produced the receptionist→doctor bug.
        IF @role_id IS NULL
        BEGIN
            RAISERROR('ManageRefreshToken: @role must be doctor, patient or receptionist.', 16, 1);
            RETURN;
        END

        DECLARE @new INT;

        BEGIN TRANSACTION;

            -- UPDLOCK + HOLDLOCK: two logins landing together must not read the
            -- same MAX(id) and collide on the primary key.
            SELECT @new = ISNULL(MAX(id), 0) + 1
            FROM dbo.RefreshTokens WITH (UPDLOCK, HOLDLOCK);

            INSERT INTO dbo.RefreshTokens
                (id, user_mobile, refresh_token, device_info, created_at, expires_at, role_id, revoked)
            VALUES
                (@new, @user_mobile, @refresh_token, @device_info, SYSUTCDATETIME(), @expires_at, @role_id, 0);

        COMMIT TRANSACTION;

        SELECT @new AS id, @role_id AS role_id;
        RETURN;
    END


    -- Get Operation ------------------------------------------------
    IF @operation = 'get'
    BEGIN
        -- SELECT * carries role_id, which is what refreshAccessToken reads.
        SELECT TOP 1 *
        FROM dbo.RefreshTokens
        WHERE refresh_token = @refresh_token
          AND revoked = 0
          AND expires_at > SYSUTCDATETIME();
        RETURN;
    END


    -- Revoke Operation ---------------------------------------------
    IF @operation = 'revoke'
    BEGIN
        -- Callers revoke every live token of one mobile (login + refresh), or a
        -- single token when they have it.
        UPDATE dbo.RefreshTokens
        SET revoked = 1
        WHERE revoked != 1
          AND (
                (@refresh_token IS NOT NULL AND refresh_token = @refresh_token)
             OR (@refresh_token IS NULL AND @user_mobile IS NOT NULL AND user_mobile = @user_mobile)
              );

        SELECT @@ROWCOUNT AS revoked_count;
        RETURN;
    END


    -- Housekeeping --------------------------------------------------
    IF @operation = 'AutoTask'
    BEGIN
        DELETE FROM dbo.RefreshTokens
        WHERE expires_at < SYSUTCDATETIME();

        DELETE FROM dbo.RefreshTokens
        WHERE id IN (
            SELECT id FROM (
                SELECT id,
                       ROW_NUMBER() OVER (
                         PARTITION BY user_mobile ORDER BY created_at DESC
                       ) AS rn
                FROM dbo.RefreshTokens
            ) t
            WHERE t.rn > 5
        );
        RETURN;
    END

    -- Invalid Operation --------------------------------------------
    SELECT 'Invalid operation. Use insert, get, revoke or AutoTask.' AS error_message;
END
GO

-- 4) Verify ------------------------------------------------------------------
-- After one receptionist login the newest row must read role_id = 3:
-- SELECT TOP 5 id, user_mobile, role_id, revoked, created_at
-- FROM dbo.RefreshTokens ORDER BY id DESC;
