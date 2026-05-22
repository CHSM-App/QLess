var express = require('express');
var router = express.Router();
var db = require('../db'); // go from admin/ to routes/
const sql = require("mssql");
const multer = require("multer");
const path = require("path");
const fs = require("fs-extra");




router.get('/fetchFamilyMembers/:family_id', async (req, res) => {
  const { family_id } = req.params;

  try {
    const request = db.request();

    request.input('operation', 'AllFamilyMembers');
    request.input('family_id', family_id);

    const result = await request.execute('sp_family_members');

    // ✅ SEND DIRECT LIST
    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to fetch Family Members ${error}`
    });
  }
});

router.get('/getDoctorAvailability/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;

  try {

    const result = await db.request()
      .input('doctor_id', doctor_id)
	  .input('operation', 'doctor_availability')
      .execute('sp_patients');

    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching doctor availability',
      error: error.message
    });
  }
});

// Active future leave ranges for a doctor — patient app greys these
// out in the appointment-date calendar.
router.get('/getDoctorLeaveDates/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;

  try {
    const result = await db.request()
      .input('operation', 'GET_LEAVE_DATES')
      .input('doctor_id', doctor_id)
      .execute('sp_doctor_leave');

    res.status(200).json(result.recordset || []);
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching doctor leave dates',
      error: error.message,
    });
  }
});

router.get('/getDoctors/:patient_id', async (req, res) => {
  const { patient_id } = req.params;
  try {

    const result = await db.request()
      .input('operation', 'getDoctors')
	  .input('patient_id', patient_id)
      .execute('sp_patients');

    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching doctor data',
      error: error.message
    });
  }
});

router.get('/patientPrescriptionList/:patient_id', async (req, res) => {
  const { patient_id } = req.params;

  try {

    const result = await db.request()
      .input('patient_id', patient_id)
	  .input('operation', 'PatientPrescriptionList')
      .execute('sp_prescription');

    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching prescription',
      error: error.message
    });
  }
});



router.get('/patientPrescriptionDetails/:prescription_id', async (req, res) => {
  const { prescription_id } = req.params;

  try {

    const result = await db.request()
      .input('prescription_id', prescription_id)
	  .input('operation', 'PrescriptionDetail')
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

router.get('/appointment/getBookedSlots/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;

  try {
    const result = await db.request()
      .input('operation', 'GET_MONTH_SLOTS')
      .input('doctor_id', doctor_id)
      .execute('sp_appointment');
	  
    res.status(200).json(result.recordset);

  } catch (error) {
    res.json({
      success: false,
      message: 'Error fetching slots',
      error: error.message
    });
  }
});


router.get('/appointment/getAvailability', async (req, res) => {
  const { doctor_id, appointment_date } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'GET_AVAILABILITY')
      .input('doctor_id', doctor_id)
      .input('appointment_date', appointment_date)
      .execute('sp_appointment');

    res.json({
      success: true,
      message: 'Availability fetched',
      data: result.recordset
    });

  } catch (error) {
    res.json({
      success: false,
      message: 'Error fetching availability',
      error: error.message
    });
  }
});


// GET PATIENT APPOINTMENTS (OPTIMIZED + ADDED NEW QUEUE FIELDS)
router.get('/getPatientAppointments/:family_id', async (req, res) => {
  const { family_id } = req.params;

  try {
    const request = db.request();

    request.input('operation', 'patient_Appointments');
    request.input('family_id', family_id);

    const result = await request.execute('sp_appointment');

    const today = new Date().toISOString().split('T')[0];

    const enrichedAppointments = [];

    for (const item of result.recordset) {
      let queueData = {
        my_queue_number: null,
        patients_ahead: null,
        estimated_arrival_time: null,
        queue_started: null,
        is_my_turn: null
      };

      const appointmentDate = new Date(item.appointment_date).toISOString().split('T')[0];

      if (appointmentDate === today) {
        try {
          const queueResult = await db.request()
            .input('operation', 'QUEUE_ESTIMATE_SMART')
            .input('appointment_id', item.appointment_id)
            .input('doctor_id', item.doctor_id)
            .execute('sp_appointment');

          if (queueResult.recordset.length > 0) {
            const q = queueResult.recordset[0];

            queueData = {
              my_queue_number: q.my_queue_number,
              patients_ahead: q.patients_ahead,
              estimated_arrival_time: q.estimated_arrival_time,
              queue_started: q.queue_started,
              is_my_turn: q.is_my_turn,
				total_queue: q?.total_queue ?? null,
        current_serving: q?.current_serving ?? null,
				queue_state: q?.status ?? null
            };
          }
        } catch (err) {
          // ignore queue error per item
        }
      }

      enrichedAppointments.push({
        ...item,
        ...queueData
      });
    }

    res.status(200).json(enrichedAppointments);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to fetch Appointment List',
      error: error.message
    });
  }
});



router.get('/favoriteDoctor/:patient_id/:doctor_id', async (req, res) => {
  try {
    const { patient_id, doctor_id } = req.params;

    const result = await db.request()
      .input('operation', 'Fetch')
      .input('patient_id', patient_id)
      .input('doctor_id', doctor_id)
      .execute('sp_favorite_doctors');

    res.status(200).json({
      is_favorite: result.recordset?.[0]?.is_favorite || 0
    });

  } catch (error) {
    console.error("Error in check favorite:", error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


router.get('/review/appointment/:appointment_id', async (req, res) => {
  try {
    const { appointment_id } = req.params;

    const result = await db.request()
      .input('operation', 'Fetch')
      .input('appointment_id', appointment_id)
      .execute('sp_review');

    res.status(200).json(result.recordset || []);

  } catch (error) {
    console.error("Error in get review by appointment:", error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ── In-app notifications inbox ─────────────────────────────────────────────
// Backed by sp_notification (INSERT/LIST/MARK_READ/MARK_ALL_READ). Doctor-side
// FCM routes call insertNotification(...) to drop rows; the patient app reads
// them here on screen open and on every FCM refresh.
router.get('/getNotifications/:patient_id', async (req, res) => {
  const { patient_id } = req.params;
  try {
    const result = await db.request()
      .input('operation', 'LIST')
      .input('patient_id', patient_id)
      .execute('sp_notification');
    res.status(200).json(result.recordset || []);
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching notifications',
      error: error.message,
    });
  }
});

router.post('/markNotificationRead', async (req, res) => {
  const { notification_id, patient_id } = req.body;
  if (!notification_id || !patient_id) {
    return res.status(400).json({
      success: false,
      message: 'notification_id and patient_id are required',
    });
  }
  try {
    await db.request()
      .input('operation', 'MARK_READ')
      .input('notification_id', notification_id)
      .input('patient_id', patient_id)
      .execute('sp_notification');
    res.status(200).json({ success: true, message: 'Marked as read' });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error marking notification',
      error: error.message,
    });
  }
});

router.post('/markAllNotificationsRead/:patient_id', async (req, res) => {
  const { patient_id } = req.params;
  try {
    await db.request()
      .input('operation', 'MARK_ALL_READ')
      .input('patient_id', patient_id)
      .execute('sp_notification');
    res.status(200).json({ success: true, message: 'All marked as read' });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error marking notifications',
      error: error.message,
    });
  }
});

// GET all reviews for doctor
router.get('/review/doctor/:doctor_id', async (req, res) => {
  try {
    const { doctor_id } = req.params;

    const result = await db.request()
      .input('operation', 'Fetch')
      .input('doctor_id', doctor_id)
      .execute('sp_review');

    res.status(200).json(result.recordset || []);

  } catch (error) {
    console.error("Error in get doctor reviews:", error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


module.exports = router; 