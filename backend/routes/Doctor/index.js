var express = require('express');
var router = express.Router();
var db = require('../db');
var sql = require('mssql');
const log = require('../middleware/logger');
const authorize = require('../middleware/authorize');
const { ROLE } = require('../middleware/roles');

// DELETE Medicine (per-doctor link unlink)
router.delete("/deleteMedicine/:doctor_id/:medicine_id", authorize(ROLE.DOCTOR), async (req, res) => {
  try {
    const { doctor_id, medicine_id } = req.params;

    if (!medicine_id || !doctor_id) {
      return res.status(400).json({
        success: false,
        message: "doctor_id and medicine_id are required"
      });
    }

    const request = db.request();
    request.input("operation", "Delete");
    request.input("doctor_id", sql.Int, parseInt(doctor_id));
    request.input("medicine_id", sql.Int, parseInt(medicine_id));

    const result = await request.execute("sp_Medicine_Master");

    // SP returns 'Medicine removed from your list.' on success
    // OR 'No medicine found to delete.' on failure
    const message = result.recordset?.[0]?.Message || "Operation completed";
    const lower = message.toLowerCase();
    const success = lower.includes("removed") || lower.includes("successfully");

    return res.status(success ? 200 : 400).json({
      success,
      message
    });

  } catch (err) {
    log.error('Error in deleteMedicine API: ' + err.message);

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete medicine"
    });
  }
});




// Clinic gallery — soft-remove selected gallery images for a clinic.
// Mounted at /doctor/index → DELETE /doctor/index/delete/clinicGallery
// Body: { clinic_id, image_urls: [..] }. SP splits @image_url on ','.
router.delete("/delete/clinicGallery", authorize(ROLE.DOCTOR), async (req, res) => {
  try {
    const { clinic_id, image_urls } = req.body;
    const urls = Array.isArray(image_urls)
      ? image_urls.map((u) => (u || "").toString().trim()).filter(Boolean)
      : [];

    if (!clinic_id || urls.length === 0) {
      return res.status(400).json({
        success: false,
        message: "clinic_id and a non-empty image_urls array are required",
      });
    }

    const result = await db.request()
      .input("operation", "deleteClinicGallery")
      .input("clinic_id", clinic_id)
      .input("image_url", urls.join(","))
      .execute("sp_doctor_login");

    const deletedCount = result.recordset?.[0]?.deleted_count ?? 0;
    return res.status(200).json({
      success: true,
      deleted_count: deletedCount,
      message: result.recordset?.[0]?.message || "Images deleted",
    });
  } catch (err) {
    log.error("Error in deleteClinicGallery API: " + err.message);
    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete clinic gallery images",
    });
  }
});



// DELETE Receptionist
router.delete("/deletereceptionist/:recep_id", authorize(ROLE.DOCTOR), async (req, res) => {
  try {
    const { recep_id } = req.params;

    if (!recep_id) {
      return res.status(400).json({
        success: false,
        message: "recep_id is required"
      });
    }

    const request = db.request();
    request.input("operation", "DeleteReceptionist");
    request.input("recep_id", sql.Int, parseInt(recep_id));

    const result = await request.execute("sp_receptionist");

    // SP returns 'Medicine removed from your list.' on success
    // OR 'No medicine found to delete.' on failure
    const message = result.recordset?.[0]?.Message || "Operation completed";
    const lower = message.toLowerCase();
    const success = lower.includes("removed") || lower.includes("successfully");

    return res.status(success ? 200 : 400).json({
      success,
      message
    });

  } catch (err) {
    log.error('Error in deleteReceptionist API: ' + err.message);

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete receptionist"
    });
  }
});


module.exports = router;