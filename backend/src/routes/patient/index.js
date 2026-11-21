var express = require('express');
var router = express.Router();
require('../../middleware/ownPatient')(router); // a patient token may only touch its own records
var db = require('../../db');
var sql = require('mssql');
const log = require('../../middleware/logger');

// DELETE Medicine
router.delete("/deleteFamilyMember/:member_id", async (req, res) => {
  try {
    const { member_id } = req.params;

    if (!member_id) {
      return res.status(400).json({
        success: false,
        message: "member_id is required"
      });
    }

    // A member with appointments or prescriptions cannot be deleted → success 0
    // row. No foreign key guards this (appointments/patient_records hold either
    // a patient or a member id, told apart by user_type = 2), so check here.
    const result = await db.request()
      .input("member_id", sql.Int, parseInt(member_id))
      .query(`
        IF EXISTS (SELECT 1 FROM dbo.appointments WHERE user_type = 2 AND patient_id = @member_id)
           OR EXISTS (SELECT 1 FROM dbo.patient_records WHERE user_type = 2 AND patient_id = @member_id)
          SELECT 0 AS success, 'Member is used in other records, cannot delete.' AS message;
        ELSE
        BEGIN TRY
          DELETE FROM dbo.family_members WHERE member_id = @member_id;
          SELECT 1 AS success, 'Member deleted successfully' AS message;
        END TRY
        BEGIN CATCH
          SELECT 0 AS success, 'Member is used in other records, cannot delete.' AS message;
        END CATCH
      `);

    const row = result.recordset?.[0] || {};
    const success = row.success === 1;

    return res.status(success ? 200 : 409).json({
      success,
      message: row.message
    });

  } catch (err) {
    log.error('Error in deleteFamily Members API: ' + err.message);

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete family Member"
    });
  }
});


// DELETE Favorite Doctor
router.delete("/favoriteDoctor/:patient_id/:doctor_id/:clinic_id", async (req, res) => {
  try {
    const { patient_id, doctor_id, clinic_id } = req.params;

    if (!patient_id || !doctor_id || !clinic_id) {
      return res.status(400).json({
        success: false,
        message: "patient_id, doctor_id, and clinic_id are required"
      });
    }

    // A favorite saved without a clinic arrives here as "null" in the URL.
    const clinic = clinic_id === 'null' ? null : clinic_id;
    const result = await db.request()
      .input("patient_id", sql.Int, parseInt(patient_id))
      .input("doctor_id", sql.Int, parseInt(doctor_id))
      .input("clinic_id", sql.NVarChar(50), clinic)
      .query(`
        DELETE FROM favorite_doctors
        WHERE patient_id = @patient_id AND doctor_id = @doctor_id
          AND (clinic_id = @clinic_id OR (clinic_id IS NULL AND @clinic_id IS NULL));
        SELECT @@ROWCOUNT AS deleted;
      `);

    if (!result.recordset?.[0]?.deleted) {
      return res.status(404).json({ success: false, message: "This doctor is not in your favorites" });
    }
    return res.status(200).json({ success: true, message: "Deleted successfully" });

  } catch (err) {
    log.error('Error in deleteFavoriteDoctor API: ' + err.message);

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete favorite doctor"
    });
  }
});



// DELETE review
router.delete('/review/:appointment_id/:patient_id', async (req, res) => {
  try {
    const { appointment_id, patient_id } = req.params;

    if (!appointment_id || !patient_id) {
      return res.status(400).json({
        success: false,
        message: "appointment_id and patient_id are required"
      });
    }

    const result = await db.request()
      .input("appointment_id", sql.Int, parseInt(appointment_id))
      .input("patient_id", sql.Int, parseInt(patient_id))
      .query(`
        DELETE FROM reviews WHERE appointment_id = @appointment_id AND patient_id = @patient_id;
        SELECT 1 AS success, 'Review deleted' AS message;
      `);

    const message = result.recordset?.[0]?.message || "Operation completed";
    const success = message.toLowerCase().includes("deleted") || message.toLowerCase().includes("success");

    return res.status(success ? 200 : 400).json({
      success,
      message
    });

  } catch (err) {
    log.error('Error in deleteReview API: ' + err.message);

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete review"
    });
  }
});


module.exports = router; 