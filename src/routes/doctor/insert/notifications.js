// /doctor/insert — Patient inbox: manual notification insert.

const express = require('express');

const {
  insertNotification,
} = require('./shared');

const router = express.Router();

// Public endpoint — same logic, exposed for any caller wanting to drop a row
// into the inbox directly (manual testing / future services).
router.post('/insertNotification', async (req, res) => {
  const { patient_id, title, body, type, ref_id } = req.body;
  if (!patient_id || !title || !body || !type) {
    return res.status(400).json({
      success: false,
      message: 'patient_id, title, body and type are required',
    });
  }
  const row = await insertNotification(patient_id, title, body, type, ref_id ?? null);
  return res.status(row.success === 1 ? 200 : 500).json({
    success: row.success === 1,
    notification_id: row.notification_id,
    message: row.message || 'Notification stored',
  });
});

module.exports = router;
