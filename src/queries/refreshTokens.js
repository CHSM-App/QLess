// SQL moved from the stored procedure ManageRefreshToken (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/refreshTokens'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Only SHA-256(token) is stored (migration 007): every batch hashes @refresh_token
// in SQL, so the token itself never touches the table.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'ManageRefreshToken',
  params: [
    { name: 'operation', type: 'NVARCHAR(20)', default: null },
    { name: 'user_mobile', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'refresh_token', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'device_info', type: 'NVARCHAR(500)', default: 'NULL' },
    { name: 'ip_address', type: 'NVARCHAR(100)', default: 'NULL' },
    { name: 'expires_at', type: 'DATETIME2', default: 'NULL' },
    { name: 'role', type: 'NVARCHAR(20)', default: 'NULL' },
  ],
  ops: {
    insert: `
BEGIN
    SET NOCOUNT ON;

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

        -- id comes from the dbo.RefreshTokens_id sequence default (migration 012).
        INSERT INTO dbo.RefreshTokens
            (user_mobile, token_hash, device_info, created_at, expires_at, role_id, revoked)
        OUTPUT inserted.id, inserted.role_id
        VALUES
            (@user_mobile, CONVERT(CHAR(64), HASHBYTES('SHA2_256', @refresh_token), 2), @device_info, SYSUTCDATETIME(), @expires_at, @role_id, 0);
        RETURN;
    END

    SELECT 'Invalid operation. Use insert, get, revoke or AutoTask.' AS error_message;
END
`,

    get: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'get'
    BEGIN
        -- SELECT * carries role_id, which is what refreshAccessToken reads.
        SELECT TOP 1 *
        FROM dbo.RefreshTokens
        WHERE token_hash = CONVERT(CHAR(64), HASHBYTES('SHA2_256', @refresh_token), 2)
          AND revoked = 0
          AND expires_at > SYSUTCDATETIME();
        RETURN;
    END

    SELECT 'Invalid operation. Use insert, get, revoke or AutoTask.' AS error_message;
END
`,

    revoke: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'revoke'
    BEGIN
        -- Callers revoke every live token of one mobile (login + refresh), or a
        -- single token when they have it.
        UPDATE dbo.RefreshTokens
        SET revoked = 1
        WHERE revoked != 1
          AND (
                (@refresh_token IS NOT NULL AND token_hash = CONVERT(CHAR(64), HASHBYTES('SHA2_256', @refresh_token), 2))
             OR (@refresh_token IS NULL AND @user_mobile IS NOT NULL AND user_mobile = @user_mobile)
              );

        SELECT @@ROWCOUNT AS revoked_count;
        RETURN;
    END

    SELECT 'Invalid operation. Use insert, get, revoke or AutoTask.' AS error_message;
END
`,
  },
  // any other @operation value (the procedure ran none of its branches)
  other: `
BEGIN
    SET NOCOUNT ON;

    SELECT 'Invalid operation. Use insert, get, revoke or AutoTask.' AS error_message;
END
`,
};
