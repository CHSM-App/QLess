// Family members (a patient's dependants): insert/update, shared by the
// patient app (/patient/insert/insertFamilyMember) and receptionist walk-in
// booking (/doctor/insert/walkInBook). SQL moved from sp_family_members.
const db = require('./db');

// Inputs go into locals typed exactly like the old procedure parameters, so
// values convert and truncate as before (DOB string → SMALLDATETIME, name cut
// to 100 characters, ...).
const TYPED_INPUTS = `
  DECLARE @v_member_id   INT           = @member_id,
          @v_family_id   INT           = @family_id,
          @v_name        NVARCHAR(100) = @name,
          @v_gender_id   INT           = @Gender_id,
          @v_relation_id INT           = @relation_id,
          @v_dob         SMALLDATETIME = @DOB,
          @v_mobile_no   NVARCHAR(50)  = @mobile_no;`;

// SQL errors are caught and returned as an { ErrorMessage, ErrorLine } row,
// as the procedure did; callers check for it.
const SQL = {
  Insert: `${TYPED_INPUTS}
    BEGIN TRY
      BEGIN TRANSACTION;
      INSERT INTO dbo.family_members (family_id, name, Gender_id, relation_id, DOB, mobile_no)
      VALUES (@v_family_id, @v_name, @v_gender_id, @v_relation_id, @v_dob, @v_mobile_no);
      SET @v_member_id = SCOPE_IDENTITY();
      COMMIT TRANSACTION;
      SELECT @v_member_id AS member_id;
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
      SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
    END CATCH`,
  Update: `${TYPED_INPUTS}
    BEGIN TRY
      BEGIN TRANSACTION;
      UPDATE dbo.family_members
      SET family_id = @v_family_id, name = @v_name, Gender_id = @v_gender_id,
          relation_id = @v_relation_id, DOB = @v_dob, mobile_no = @v_mobile_no
      WHERE member_id = @v_member_id;
      DECLARE @updated INT = @@ROWCOUNT;
      COMMIT TRANSACTION;
      SELECT @v_member_id AS member_id, @updated AS updated;
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
      SELECT ERROR_MESSAGE() AS ErrorMessage, ERROR_LINE() AS ErrorLine;
    END CATCH`,
};

/**
 * @param {'Insert'|'Update'} operation
 * @param {object} m  member_id, family_id, name, Gender_id, relation_id, DOB, mobile_no
 * @returns the mssql result: recordset[0] is { member_id } (Update adds { updated: 0|1 }) or { ErrorMessage, ErrorLine }
 */
function saveFamilyMember(operation, m) {
  return db.request()
    .input('member_id', m.member_id)
    .input('family_id', m.family_id)
    .input('name', m.name)
    .input('Gender_id', m.Gender_id)
    .input('relation_id', m.relation_id)
    .input('DOB', m.DOB)
    .input('mobile_no', m.mobile_no)
    .query(SQL[operation]);
}

module.exports = { saveFamilyMember };
