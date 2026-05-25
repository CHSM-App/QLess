var express = require('express');
var router = express.Router();
var db = require('../db'); 
var sql = require('mssql');

// DELETE Medicine (per-doctor link unlink)
router.delete("/deleteMedicine/:doctor_id/:medicine_id", async (req, res) => {
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
    console.error("Error in deleteMedicine API:", err);

    return res.status(500).json({
      success: false,
      message: err.message || "Failed to delete medicine"
    });
  }
});




module.exports = router; 