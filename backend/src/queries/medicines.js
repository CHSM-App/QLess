// SQL moved from the stored procedure sp_Medicine_Master (src/migrations/000_baseline.sql).
// One batch per @operation the app calls, run with
//   db.request().input('operation', '<OP>').input(...).run(require('../queries/medicines'))
// The parameters below become typed locals (see run() in src/db.js), so values
// convert, truncate and default exactly as they did as procedure parameters.
// Split mechanically from the procedure body and checked against it on a real
// database; edit like any other code from here on.
module.exports = {
  procedure: 'sp_Medicine_Master',
  params: [
    { name: 'operation', type: 'NVARCHAR(20)', default: 'NULL' },
    { name: 'medicine_id', type: 'INT', default: '0' },
    { name: 'doctor_id', type: 'INT', default: '0' },
    { name: 'medicine_name', type: 'NVARCHAR(100)', default: 'NULL' },
    { name: 'medicine_type_id', type: 'INT', default: 'NULL' },
    { name: 'search_query', type: 'NVARCHAR(100)', default: 'NULL' },
    { name: 'brand_name', type: 'NVARCHAR(200)', default: 'NULL' },
    { name: 'strength', type: 'NVARCHAR(50)', default: 'NULL' },
    { name: 'components', type: 'NVARCHAR(500)', default: 'NULL' },
  ],
  ops: {
    Insert: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'Insert'
    BEGIN
        DECLARE @medId INT;

        -- 1. Medicine_Master madhe (name+type+brand+strength) ahe ka check
        SELECT @medId = medicine_id
        FROM dbo.Medicine_Master
        WHERE medicine_name    = @medicine_name
          AND medicine_type_id = @medicine_type_id
          AND ISNULL(brand_name, '') = ISNULL(@brand_name, '')
          AND ISNULL(strength, '')   = ISNULL(@strength, '');

        -- 2. Naselich tar global library madhe insert
        IF @medId IS NULL
        BEGIN
            INSERT INTO dbo.Medicine_Master (medicine_name, medicine_type_id, brand_name, strength, components)
            VALUES (@medicine_name, @medicine_type_id, @brand_name, @strength, @components);
            SET @medId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- Existing row la components nasel tar bharun ghya
            UPDATE dbo.Medicine_Master
            SET    components = @components
            WHERE  medicine_id = @medId
              AND  components IS NULL
              AND  @components IS NOT NULL;
        END

        -- 3. Already active link asla ? duplicate prevent
        IF EXISTS (
            SELECT 1 FROM dbo.Doctor_Medicine
            WHERE doctor_id   = @doctor_id
              AND medicine_id = @medId
              AND is_active   = 1
        )
        BEGIN
            SELECT 'Medicine already in your list.' AS Message, @medId AS medicine_id;
            RETURN;
        END

        -- 4. Soft-deleted link asla ? reactivate
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

            SELECT 'Medicine reactivated.' AS Message, @medId AS medicine_id;
            RETURN;
        END

        -- 5. Navin link insert
        INSERT INTO dbo.Doctor_Medicine (doctor_id, medicine_id, is_active)
        VALUES (@doctor_id, @medId, 1);

        SELECT 'Medicine added successfully.' AS Message, @medId AS medicine_id;
    END

END
`,

    getMedicineTypes: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'getMedicineTypes'
    BEGIN
        SELECT * FROM dbo.Medicine_Type;
    END

END
`,

    fetchAllMedicines: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'fetchAllMedicines'
    BEGIN
        SELECT
            m.medicine_id,
            dm.doctor_id,
            m.medicine_name,
            m.medicine_type_id,
            t.Medi_Type_Name,
            m.brand_name,
            m.strength,
            m.components
        FROM   dbo.Doctor_Medicine dm
        INNER JOIN dbo.Medicine_Master m ON dm.medicine_id    = m.medicine_id
        INNER JOIN dbo.Medicine_Type   t ON m.medicine_type_id = t.medicine_type_id
        WHERE  dm.doctor_id = @doctor_id
          AND  dm.is_active = 1
        ORDER BY m.medicine_name;
    END

END
`,

    getSuggestions: `
BEGIN
    SET NOCOUNT ON;

    IF @operation = 'getSuggestions'
    BEGIN
        SELECT TOP 20
            m.medicine_id,
            m.medicine_name,
            m.medicine_type_id,
            t.Medi_Type_Name,
            m.brand_name,
            m.strength,
            m.components
        FROM   dbo.Medicine_Master m
        INNER JOIN dbo.Medicine_Type t ON m.medicine_type_id = t.medicine_type_id
        WHERE  m.medicine_name LIKE @search_query + '%'
           OR  m.brand_name    LIKE @search_query + '%'
        ORDER BY m.medicine_name;
    END

END
`,

    Delete: `
BEGIN
    SET NOCOUNT ON;

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
`,
  },
  // any other @operation value (the procedure ran none of its branches)
  other: `
BEGIN
    SET NOCOUNT ON;

END
`,
};
