// SQL moved from the stored procedure sp_receptionist (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/receptionists'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'sp_receptionist',
  params: [
    { name: 'operation', type: 'NVARCHAR(50)', default: null },
    { name: 'recep_id', type: 'INT', default: 'NULL' },
    { name: 'mobile_no', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'name', type: 'NVARCHAR(100)', default: 'NULL' },
    { name: 'Address', type: 'NVARCHAR(100)', default: 'NULL' },
    { name: 'email', type: 'NVARCHAR(100)', default: 'NULL' },
    { name: 'gender_id', type: 'INT', default: 'NULL' },
    { name: 'clinic_id', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'img_url', type: 'NVARCHAR(MAX)', default: 'NULL' },
    { name: 'doctor_id', type: 'INT', default: 'NULL' },
  ],
  ops: {
    Insert: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'Insert'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            IF EXISTS
            (
                SELECT 1
                FROM receptionist
                WHERE mobile_no = @mobile_no
                AND active_status = 1
            )
            BEGIN
                SELECT
                    0 AS success,
                    'Mobile number already exists' AS message;

                ROLLBACK TRANSACTION;
                RETURN;
            END
			 IF EXISTS
        (
            SELECT 1
            FROM doctor_login
            WHERE mobile = @mobile_no
            AND active_status = 1
        )
        BEGIN
            SELECT 0 AS success, 'This mobile is already registered as a Doctor' AS message;
            ROLLBACK TRANSACTION;
            RETURN;
        END

            INSERT INTO receptionist
            (
                name,
                mobile_no,
                email,
                Address,
                gender_id,
                clinic_id,
                active_status,
                created_at,
				role_id,
				doctor_id
            )
            VALUES
            (
                @name,
                @mobile_no,
                @email,
                @Address,
                @gender_id,
                @clinic_id,
                1,
                GETDATE(),
				3,
				@doctor_id
            );

            SET @recep_id = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            SELECT
                1 AS success,
                @recep_id AS recep_id,
                'Receptionist created successfully' AS message;

        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;

            SELECT
                0 AS success,
                ERROR_MESSAGE() AS message;
        END CATCH

        RETURN;
    END

END
`,

    Update: `
BEGIN
    SET NOCOUNT ON;

  IF @operation = 'Update'
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE receptionist
        SET
            name      = ISNULL(@name,      name),
            mobile_no = ISNULL(@mobile_no, mobile_no),
            email     = ISNULL(@email,     email),
            Address   = ISNULL(@Address,   Address),
            gender_id = ISNULL(@gender_id, gender_id),
            clinic_id = ISNULL(@clinic_id, clinic_id),
            doctor_id = ISNULL(@doctor_id, doctor_id)
        WHERE recep_id = @recep_id;

        COMMIT TRANSACTION;

        SELECT
            1 AS success,
            @recep_id AS recep_id,
            'Receptionist updated successfully' AS message;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 0 AS success, ERROR_MESSAGE() AS message;
    END CATCH

    RETURN;
END

END
`,

    FetchReceptionistList: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'FetchReceptionistList'
    BEGIN
        SELECT *
        FROM receptionist
        WHERE active_status = 1 and doctor_id=@doctor_id
        ORDER BY recep_id DESC;

        RETURN;
    END

END
`,

    DeleteReceptionist: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'DeleteReceptionist'
    BEGIN
        UPDATE receptionist
        SET active_status = 0
        WHERE recep_id = @recep_id;

        SELECT
            1 AS success,
            'Receptionist deleted successfully' AS message;

        RETURN;
    END

END
`,

    uploadReceptionistImg: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'uploadReceptionistImg'
    BEGIN
        UPDATE receptionist
        SET img_url = @img_url
        WHERE recep_id = @recep_id;

        SELECT
            1 AS success,
            'Image uploaded successfully' AS message;

        RETURN;
    END

END
`,

    check_phone_receptionist: `
BEGIN
    SET NOCOUNT ON;

	IF @operation = 'check_phone_receptionist'
    BEGIN
        SELECT
            recep_id,
            name,
            mobile_no,
            email,
            Address,
            gender_id,
            clinic_id,
            doctor_id,
            img_url,
            active_status,
            created_at,
            role_id,
            token
        FROM receptionist
        WHERE mobile_no = @mobile_no
        AND active_status = 1;
        RETURN;
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
