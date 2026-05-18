var express = require('express');
var router = express.Router();
var db = require('../db'); 
var sql = require('mssql');

// DELETE Medicine
router.delete("/deleteMedicine/:medicine_id", async (req, res) => {
  try {
    const { medicine_id } = req.params;

    if (!medicine_id) {
      return res.status(400).json({
        success: false,
        message: "medicine_id is required"
      });
    }

    const request = db.request();
    request.input("operation", "Delete");
    request.input("medicine_id", sql.Int, parseInt(medicine_id));

    const result = await request.execute("sp_Medicine_Master");

    // The SP returns a message like 'Medicine deleted successfully.' or error message
    const message = result.recordset?.[0]?.Message || "Operation completed";

    // Determine success based on message
    const success = message.toLowerCase().includes("successfully");

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