var express = require('express');
var router = express.Router();
var db = require('../db');
var sql = require('mssql');
const log = require('../middleware/logger');

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

    const request = db.request();
    request.input("operation", "DeleteMember");
    request.input("member_id", sql.Int, parseInt(member_id));

    const result = await request.execute("sp_family_members");

    // The SP returns a message like 'Family Member deleted successfully.' or error message
    const message = result.recordset?.[0]?.Message || "Operation completed";

    // Determine success based on message
    const success = message.toLowerCase().includes("successfully");

    return res.status(success ? 200 : 400).json({
      success,
      message
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
router.delete("/favoriteDoctor/:patient_id/:doctor_id", async (req, res) => {
  try {
    const { patient_id, doctor_id } = req.params;

    if (!patient_id || !doctor_id) {
      return res.status(400).json({
        success: false,
        message: "patient_id and doctor_id are required"
      });
    }

    const request = db.request();
    request.input("operation", "Delete");
    request.input("patient_id", sql.Int, parseInt(patient_id));
    request.input("doctor_id", sql.Int, parseInt(doctor_id));

    const result = await request.execute("sp_favorite_doctors");

    // The SP returns a message like 'Deleted successfully' or error
    const message = result.recordset?.[0]?.message || "Operation completed";

    // Determine success based on message
    const success = message.toLowerCase().includes("successfully");

    return res.status(success ? 200 : 400).json({
      success,
      message
    });

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

    const request = db.request();
    request.input("operation", "Delete");
    request.input("appointment_id", sql.Int, parseInt(appointment_id));
    request.input("patient_id", sql.Int, parseInt(patient_id));

    const result = await request.execute("sp_review");

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