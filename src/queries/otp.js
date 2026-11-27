// SQL moved from the stored procedure sp_otp (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/otp'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'sp_otp',
  params: [
    { name: 'operation', type: 'VARCHAR(20)', default: null },
    { name: 'mobile_no', type: 'VARCHAR(15)', default: null },
    { name: 'otp_hash', type: 'VARCHAR(255)', default: 'NULL' },
  ],
  ops: {
    send_otp: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'send_otp'
    BEGIN
        -- Rate limit: max 3 OTP in last 10 min
        IF (
            SELECT COUNT(*)
            FROM otp_verification
            WHERE mobile_no = @mobile_no
            AND created_at > DATEADD(MINUTE, -10, GETDATE())
        ) >= 3
        BEGIN
            SELECT 0 AS status, 'Too many OTP requests. Try later.' AS message;
            RETURN;
        END

        -- Delete old OTPs (optional cleanup)
        DELETE FROM otp_verification
        WHERE mobile_no = @mobile_no;

        -- Insert new OTP
        INSERT INTO otp_verification (
            mobile_no, otp_hash, expires_at
        )
        VALUES (
            @mobile_no,
            @otp_hash,
            DATEADD(MINUTE, 5, GETDATE()) -- 5 min expiry
        );

        SELECT 1 AS status, 'OTP sent successfully' AS message;
    END

END
`,

    verify_otp: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'verify_otp'
    BEGIN
        DECLARE @id INT,
                @db_otp_hash VARCHAR(255),
                @expires_at DATETIME,
                @attempts INT,
                @is_verified BIT;

        -- Get latest OTP
        SELECT TOP 1
            @id = id,
            @db_otp_hash = otp_hash,
            @expires_at = expires_at,
            @attempts = attempts,
            @is_verified = is_verified
        FROM otp_verification
        WHERE mobile_no = @mobile_no
        ORDER BY created_at DESC;

        IF @id IS NULL
        BEGIN
            SELECT 0 AS status, 'OTP not found' AS message;
            RETURN;
        END

        IF @is_verified = 1
        BEGIN
            SELECT 0 AS status, 'OTP already used' AS message;
            RETURN;
        END

        IF @expires_at < GETDATE()
        BEGIN
            SELECT 0 AS status, 'OTP expired' AS message;
            RETURN;
        END

        IF @attempts >= 5
        BEGIN
            SELECT 0 AS status, 'Too many attempts. Try again later.' AS message;
            RETURN;
        END

        -- Return hash to Node.js for comparison
        SELECT
            1 AS status,
            @id AS otp_id,
            @db_otp_hash AS otp_hash,
            @attempts AS attempts;
    END

END
`,

    update_attempt: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'update_attempt'
    BEGIN
        UPDATE otp_verification
        SET attempts = attempts + 1
        WHERE mobile_no = @mobile_no;

        SELECT 1 AS status;
    END

END
`,

    mark_verified: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'mark_verified'
    BEGIN
        UPDATE otp_verification
        SET is_verified = 1
        WHERE mobile_no = @mobile_no;

        SELECT 1 AS status;
    END
END
`,
  },
  // any other @operation value (the procedure ran none of its branches)
  other: `
BEGIN
    SET NOCOUNT ON;

END
`,
};
