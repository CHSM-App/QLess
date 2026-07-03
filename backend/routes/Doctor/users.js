var express = require('express');
var router = express.Router();
var db = require('../db'); // go from admin/ to routes/
const sql = require("mssql");
const multer = require("multer");
const path = require("path");

const fs = require("fs-extra");
// Auto-close sweep for previous-day sessions (cancel + notify). Shared from the
// insert router so getTodayQueue can self-heal stale data on demand.
const { closeStaleSessions } = require('./insert');


router.get('/getMedicineTypes', async (req, res) => {
  try {
    const request = db.request();

    request.input('operation', 'getMedicineTypes');

    const result = await request.execute('sp_Medicine_Master'); // change if needed

    res.status(200).json(
      result.recordset
    );

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to fetch medicine types ${error}`
    });
  }
});


router.get('/getMedicineSuggestions', async (req, res) => {
  const { q } = req.query;

  if (!q || q.toString().trim().length === 0) {
    return res.status(200).json([]);
  }

  try {
    const request = db.request();
    request.input('operation', 'getSuggestions');
    request.input('search_query', q.toString().trim());

    const result = await request.execute('sp_Medicine_Master');
    res.status(200).json(result.recordset);
  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to fetch suggestions ${error}`
    });
  }
});


router.get('/getAllMedicines/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;

  try {
    const request = db.request();

    request.input('operation', 'fetchAllMedicines');
    request.input('doctor_id', doctor_id);

    const result = await request.execute('sp_Medicine_Master');

    res.status(200).json(
      result.recordset
    );

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to fetch medicines ${error}`
    });
  }
});

router.get('/getDoctorSchedule/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;
  const { clinic_id } = req.query;

  try {

    const req2 = db.request()
      .input('operation', 'GET')
      .input('doctor_id', doctor_id);
    if (clinic_id) req2.input('clinic_id', clinic_id);
    const result = await req2.execute('sp_doctor_schedule');

    const rows = result.recordset;

    const grouped = {};

    for (const row of rows) {

      if (!grouped[row.day_of_week]) {
        grouped[row.day_of_week] = {
          day: row.day_of_week,
          is_enabled: row.is_enabled ? 1 : 0,
          slots: []
        };
      }



      if (row.slot_id) {
        grouped[row.day_of_week].slots.push({
          slot_id: row.slot_id,
          start_time: row.start_time,   // already HH:mm
          end_time: row.end_time,
          booking_mode: row.booking_mode,
          slot_duration: row.slot_duration,
          max_queue_length: row.max_queue_length
        });
      }
    }

    const schedule = Object.values(grouped);

    res.status(200).json({
      doctor_id: parseInt(doctor_id),
      schedule: schedule
    });

  } catch (error) {

    res.status(500).json({
      success: false,
      message: 'Error fetching schedule',
      error: error.message
    });

  }
});



router.get('/patientAppointmentList/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;
  const { clinic_id } = req.query;

  try {
    const request = db.request();

    request.input('operation', 'patientAppointmentList');
    request.input('doctor_id', doctor_id);
    if (clinic_id) request.input('clinic_id', clinic_id);

    const result = await request.execute('sp_appointment');

    res.status(200).json(
      result.recordset
    );

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to fetch Appointment List ${error}`
    });
  }
});
router.get('/appointmentWisePrescription/:appointment_id', async (req, res) => {
  const { appointment_id } = req.params;

  try {

    const result = await db.request()
      .input('appointment_id', appointment_id)
      .input('operation', 'AppointmentWisePrescription')
      .execute('sp_prescription');

    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching prescription details',
      error: error.message
    });
  }
});


// GET TODAY QUEUE
router.get('/appointment/getTodayQueue/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;
  const { clinic_id } = req.query;

  if (!doctor_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id required'
    });
  }

  try {
    // Self-heal: close any previous-day session (cancel its lapsed patients +
    // notify) before reading, so a doctor opening the app never sees stale data
    // even if the nightly cron / startup catch-up was missed. No-op on normal days.
    try { await closeStaleSessions(); } catch (e) { /* never block the read */ }

    const req2 = db.request()
      .input('operation', 'GET_TODAY_QUEUE')
      .input('doctor_id', doctor_id);
    if (clinic_id) req2.input('clinic_id', clinic_id);
    const result = await req2.execute('sp_appointment');

    const rows = result.recordsets?.[0] || [];
    const statusRow = result.recordsets?.[1]?.[0] || {};

    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow || 'Failed to fetch queue'
      });
    }

    // Enrich with booking_closed (the "stop new bookings" toggle) — sp_appointment's
    // GET_TODAY_QUEUE doesn't return it, so fetch it directly rather than touch the SP.
    const queueIds = rows.map(r => r.queue_id).filter(id => id != null);
    if (queueIds.length > 0) {
      const bcRes = await db.request().query(`
        SELECT queue_id, booking_closed FROM doctor_queue
        WHERE queue_id IN (${queueIds.map(id => Number(id)).join(',')})
      `);
      const bcMap = new Map((bcRes.recordset || []).map(r => [r.queue_id, r.booking_closed]));
      for (const r of rows) r.booking_closed = bcMap.get(r.queue_id) === true;
    }

    return res.json(rows);

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch queue',
      error: error.message
    });
  }
});





// Clinic gallery — list active gallery images for a clinic.
// Mounted at /doctor/users → GET /doctor/users/clinicGallery/:clinic_id
router.get('/clinicGallery/:clinic_id', async (req, res) => {
  try {
    const { clinic_id } = req.params;
    if (!clinic_id) {
      return res.status(400).json({ success: false, message: 'clinic_id is required' });
    }
    const result = await db.request()
      .input('operation', 'fetchClinicGallery')
      .input('clinic_id', clinic_id)
      .execute('sp_doctor_login');
    return res.status(200).json(result.recordset);
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch clinic gallery',
      error: error.message,
    });
  }
});



router.get('/getDoctorsByClinic/:clinic_id', async (req, res) => {
  const { clinic_id } = req.params;
  try {
    const result = await db.request()
      .input('operation', 'FetchDoctors')
      .input('clinic_id', clinic_id)
      .execute('sp_doctor_login');
    res.status(200).json(result.recordset);
  } catch (error) {
    res.status(500).json({ success: 0, message: `Failed to fetch clinic doctors: ${error.message}` });
  }
});



router.get('/fetchReceptionistList/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;
  console.log('[ReceptionistDebug] fetchReceptionistList doctor_id:', doctor_id);

  try {
    const request = db.request();

    request.input('operation', 'FetchReceptionistList');
    request.input('doctor_id', doctor_id);

    const result = await request.execute('sp_receptionist');
    console.log(
      '[ReceptionistDebug] fetchReceptionistList count:',
      result.recordset?.length || 0
    );

    res.status(200).json(result.recordset);

  } catch (error) {
    console.error('[ReceptionistDebug] fetchReceptionistList error:', error);
    res.status(500).json({
      success: 0,
      message: `Failed to fetch receptionist list: ${error.message}`
    });
  }
});



module.exports = router; 
