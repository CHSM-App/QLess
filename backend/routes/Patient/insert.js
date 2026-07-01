var express = require('express');
var router = express.Router();
var db = require('../db'); // go from admin/ to routes/
const sql = require("mssql");
const multer = require("multer");
const log = require('../middleware/logger');
const path = require("path");
const fs = require("fs-extra");

function emitQueueUpdate(req, event, doctor_id, extra = {}) {
  const io = req.app.get('io');
  if (io && doctor_id) io.to('clinic_' + doctor_id).emit('queue_update', { event, doctor_id, ...extra });
}


router.post('/insertFamilyMember', async (req, res) => {
  try {
    const {
      member_id,
      family_id,
      name,
      Gender_id,
      relation_id,
      DOB,
      mobile_no
    } = req.body;

    const clean = (v) => (v === "" ? null : v);

    const operation = member_id && member_id > 0 ? "Update" : "Insert";

    const result = await db.request()
      .input('operation', operation)
      .input('member_id', member_id || null)
      .input('family_id', family_id)
      .input('name', clean(name))
      .input('Gender_id', Gender_id || null)
      .input('relation_id', relation_id || null)
      .input('DOB', DOB || null)
      .input('mobile_no', clean(mobile_no))
      .execute('sp_family_members');

    // ✅ Handle SQL error
    if (result.recordset?.[0]?.ErrorMessage) {
      return res.status(500).json({
        success: false,
        error: result.recordset[0].ErrorMessage
      });
    }

    return res.status(200).json({
      success: true,
      member_id: result.recordset?.[0]?.member_id,
      message:
        operation === "Update"
          ? "Family member updated successfully"
          : "Family member added successfully"
    });

  } catch (error) {
    log.error('Error in /addFamilyMember: ' + error.message);

    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});



router.post('/appointment/book', async (req, res) => {
  const { doctor_id, patient_id, appointment_date, start_time, user_type, slot_id, symptoms, clinic_id } = req.body;

  try {
    // Hard-guard: reject booking if the doctor is on leave that date
    // (defense in depth — patient UI also greys these dates out).
    const blockRes = await db.request()
      .input('operation', 'IS_BLOCKED')
      .input('doctor_id', doctor_id)
      .input('from_date', appointment_date)
      .execute('sp_doctor_leave');

    if (blockRes.recordset?.[0]?.blocked === 1) {
      return res.json({
        success: false,
        message: 'Doctor is on leave on this date. Please pick another date.',
      });
    }

    const result = await db.request()
      .input('operation', 'BOOK')
      .input('user_type', user_type)
      .input('doctor_id', doctor_id)
      .input('patient_id', patient_id)
      .input('appointment_date', appointment_date)
      .input('start_time', start_time)
      .input('slot_id', slot_id)
      .input('symptoms', symptoms)
      .input('clinic_id', clinic_id || null)
      .execute('sp_appointment');

    const booked = result.recordset[0].success === 1;
    if (booked) emitQueueUpdate(req, 'booked', doctor_id);
    res.json({ success: booked, message: result.recordset[0].message });

  } catch (error) {
    res.json({
      success: false,
      message: 'Booking failed',
      error: error.message
    });
  }
});

router.post('/appointment/cancel', async (req, res) => {
  const { appointment_id } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'CANCEL')
      .input('appointment_id', appointment_id)
      .execute('sp_appointment');

    res.json({
      success: true,
      message: result.recordset[0].message
    });

  } catch (error) {
    res.json({
      success: false,
      message: 'Cancel failed',
      error: error.message
    });
  }
});

router.post('/appointment/queueStatus', async (req, res) => {
  const { doctor_id, appointment_date } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'QUEUE_STATUS')
      .input('doctor_id', doctor_id)
      .input('appointment_date', appointment_date)
      .execute('sp_appointment');

    res.json({
      success: true,
      message: 'Queue status fetched',
      data: result.recordset
    });

  } catch (error) {
    res.json({
      success: false,
      message: 'Error fetching queue',
      error: error.message
    });
  }
});




router.post('/favoriteDoctor/add', async (req, res) => {
  const { patient_id, doctor_id, clinic_id } = req.body;

  if (!patient_id || !doctor_id) {
    return res.status(400).json({ success: false, message: 'patient_id and doctor_id are required' });
  }

  try {
    const result = await db.request()
      .input('operation', 'Insert')
      .input('patient_id', patient_id)
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_favorite_doctors');

    res.status(200).json({
      success: true,
      message: 'Doctor added to favorites',
      favorite_id: result.recordset?.[0]?.favorite_id
    });

  } catch (error) {
    log.error('Error in /favoriteDoctor/add: ' + error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});




// ADD review
router.post('/review/add', async (req, res) => {
  const { appointment_id, doctor_id, patient_id, rating, comment, reviewed_by_user_id, clinic_id } = req.body;

  if (!appointment_id || !doctor_id || !patient_id || !rating || !reviewed_by_user_id) {
    return res.status(400).json({
      success: false,
      message: 'appointment_id, doctor_id, patient_id, rating, reviewed_by_user_id required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'Insert')
      .input('appointment_id', appointment_id)
      .input('doctor_id', doctor_id)
      .input('patient_id', patient_id)
      .input('rating', rating)
      .input('comment', comment || '')
      .input('reviewed_by_user_id', reviewed_by_user_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_review');

    res.status(200).json({
      success: result.recordset?.[0]?.success ?? true,
      message: result.recordset?.[0]?.message || 'Review added',
      review_id: result.recordset?.[0]?.review_id
    });

  } catch (error) {
    log.error('Error in /review/add: ' + error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});



router.post('/rescheduleAppointment', async (req, res) => {
  const {
    appointment_id,
    doctor_id,
    appointment_date,
    start_time,
    slot_id,
    symptoms
  } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'RESCHEDULE_APPOINTMENT')
      .input('appointment_id', appointment_id)
      .input('doctor_id', doctor_id)
      .input('appointment_date', appointment_date)
      .input('start_time', start_time)
      .input('slot_id', slot_id)
      .input('symptoms', symptoms)

      .execute('sp_appointment');

    emitQueueUpdate(req, 'rescheduled', doctor_id);
    res.status(200).json({
      success: true,
      message: result.recordset[0]?.message || 'Operation completed'
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error while rescheduling appointment',
      error: error.message
    });
  }
});

router.post('/cancelAppointment/:appointment_id', async (req, res) => {
  const { appointment_id } = req.params;

  try {
    // Look up doctor_id before cancelling so we can notify the room.
    let doctor_id = null;
    try {
      const dr = await db.request()
        .input('appointment_id', appointment_id)
        .query('SELECT TOP 1 doctor_id FROM appointments WHERE appointment_id = @appointment_id');
      doctor_id = dr.recordset?.[0]?.doctor_id ?? null;
    } catch (_) { }

    const result = await db.request()
      .input('operation', 'CANCEL_APPOINTMENT')
      .input('appointment_id', appointment_id)
      .execute('sp_appointment');

    emitQueueUpdate(req, 'patient_cancelled', doctor_id);
    res.status(200).json({
      success: result.recordset[0]?.success || true,
      message: result.recordset[0]?.message || 'Appointment cancelled successfully'
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error while cancelling appointment',
      error: error.message
    });
  }
});


router.post('/queueEstimate', async (req, res) => {
  const {
    appointment_id,
    doctor_id,
    clinic_id
  } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'QUEUE_ESTIMATE_SMART')
      .input('appointment_id', appointment_id)
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_appointment');

    res.status(200).json(result.recordset[0]);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error while fetching queue estimate',
      error: error.message
    });
  }
});

router.post('/queuePreviewEstimate', async (req, res) => {
  const {
    doctor_id,
    slot_id,
    clinic_id
  } = req.body;

  try {
    const result = await db.request()
      .input('operation', 'QUEUE_PREVIEW_ESTIMATE')
      .input('doctor_id', doctor_id)
      .input('slot_id', slot_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_appointment');

    res.status(200).json(result.recordset[0]);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error while fetching queue preview estimate',
      error: error.message
    });
  }
});


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
              total_queue: q.total_queue,
              current_serving: q.current_serving,
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

    res.status(200).json(
      enrichedAppointments
    );

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Failed to fetch Appointment List',
      error: error.message
    });
  }
});


module.exports = router; 