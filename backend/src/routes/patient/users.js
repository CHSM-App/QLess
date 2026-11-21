var express = require('express');
var router = express.Router();
require('../../middleware/ownPatient')(router); // a patient token may only touch its own records
const ownStaff = require('../../middleware/ownStaff');
const { ROLE } = require('../../middleware/roles');
// Patient-app routes. Clinic staff use only the walk-in family lookup and the
// prescription history (their own doctor's prescriptions only), plus the
// public doctor catalogue reads; every other route is patients-only.
const STAFF_OK = /^\/(fetchFamilyMembers|patientPrescriptionList|patientPrescriptionDetails|getDoctorAvailability|getDoctorLeaveDates|appointment\/getBookedSlots|appointment\/getAvailability|review\/doctor)(\/|$)/;
router.use((req, res, next) => (Number(req.user && req.user.role_id) !== ROLE.PATIENT
  && !(ownStaff.isStaff(req) && STAFF_OK.test(req.path))
  ? res.status(403).json({ msg: 'Your account does not have access to this action.' })
  : next()));
ownStaff(router); // staff: patient_id must have seen their doctor, prescription_id be written by them
var db = require('../../db');
const sql = require("mssql");
const multer = require("multer");
const log = require('../../middleware/logger');
const path = require("path");
const fs = require("fs-extra");
const doctorLeaveSql = require('../../queries/doctorLeave');
const notificationsSql = require('../../queries/notifications');
const prescriptionsSql = require('../../queries/prescriptions');
const patientsSql = require('../../queries/patients');
const appointmentsSql = require('../../queries/appointments');

// The furthest token the queue has actually reached — the largest
// queue_number N such that every token from 1..N-1 is fully resolved
// (completed, cancelled, or skipped) and token N itself is in_progress,
// completed, cancelled, or skipped. An in_progress token is NOT yet
// resolved, so nothing after it (even a cancelled token) can count as
// "reached" until it finishes. Cancelled/skipped tokens are bypassed as
// soon as they're marked; a skipped patient who is later recalled and
// served does not pull current_serving back to their number.
// This is the SAME rule the doctor's GET_TODAY_QUEUE and the socket
// `fetchCurrentServing` use, so every surface shows one value.
// We compute it here to override sp_appointment's QUEUE_ESTIMATE_SMART, whose
// current_serving lags/miscounts for the patient list.
async function correctCurrentServing(appointment_id) {
  try {
    const res = await db.request()
      .input('appointment_id', sql.Int, parseInt(appointment_id))
      .query(`
        SELECT MAX(a.queue_number) AS current_serving
        FROM   appointments a
        WHERE  a.queue_id = (SELECT queue_id FROM appointments WHERE appointment_id = @appointment_id)
          AND  a.status   IN ('in_progress', 'completed', 'cancelled', 'cancled', 'skipped')
          AND  NOT EXISTS (
                 -- any strictly-earlier token still not resolved (booked or
                 -- itself in_progress) blocks this one from counting
                 SELECT 1 FROM appointments b
                 WHERE  b.queue_id = a.queue_id
                   AND  b.booking_type = 1
                   AND  b.queue_number < a.queue_number
                   AND  b.status NOT IN ('completed', 'cancelled', 'cancled', 'skipped')
               )
      `);
    return res.recordset[0]?.current_serving ?? null;
  } catch (_) {
    return null;
  }
}


router.get('/fetchFamilyMembers/:family_id', async (req, res) => {
  const { family_id } = req.params;

  try {
    const result = await db.request()
      .input('family_id', sql.Int, family_id)
      .query(`
        SELECT fm.member_id, fm.family_id, fm.name, fm.Gender_id, g.Gender,
               fm.relation_id, r.relation, fm.DOB, fm.mobile_no
        FROM dbo.family_members fm
        LEFT JOIN Gender g ON fm.Gender_id = g.gender_id
        LEFT JOIN Relations r ON fm.relation_id = r.relation_id
        WHERE family_id = @family_id
      `);

    // ✅ SEND DIRECT LIST
    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to fetch Family Members ${error}`
    });
  }
});

router.get('/getDoctorAvailability/:doctor_id/:clinic_id', async (req, res) => {
  const { doctor_id, clinic_id } = req.params;

  try {

    const result = await db.request()
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .input('operation', 'doctor_availability')
      .run(patientsSql);

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
router.get('/getDoctorLeaveDates/:doctor_id/:clinic_id', async (req, res) => {
  const { doctor_id, clinic_id } = req.params;

  try {
    const result = await db.request()
      .input('operation', 'GET_LEAVE_DATES')
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id)
      .run(doctorLeaveSql);

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
      .run(patientsSql);

    const doctors = result.recordset;
    const today = new Date().toISOString().split('T')[0];

    // Parallel leave-check for each doctor (IS_BLOCKED covers today's date)
    const leaveResults = await Promise.all(
      doctors.map(async (d) => {
        if (!d.doctor_id) return { doctor_id: d.doctor_id, blocked: 0 };
        try {
          const r = await db.request()
            .input('operation', 'IS_BLOCKED')
            .input('doctor_id', d.doctor_id)
            .input('from_date', today)
            .run(doctorLeaveSql);
          return { doctor_id: d.doctor_id, blocked: r.recordset?.[0]?.blocked ?? 0 };
        } catch { return { doctor_id: d.doctor_id, blocked: 0 }; }
      })
    );

    const leaveMap = {};
    leaveResults.forEach(l => { leaveMap[l.doctor_id] = l.blocked; });

    res.status(200).json(
      doctors.map(d => ({ ...d, is_on_leave: leaveMap[d.doctor_id] ?? 0 }))
    );
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

    // Staff get only the prescriptions their own doctor wrote.
    const request = db.request()
      .input('patient_id', patient_id)
      .input('operation', 'PatientPrescriptionList');
    if (ownStaff.isStaff(req)) request.input('doctor_id', await ownStaff.staffDoctorId(req));
    const result = await request.run(prescriptionsSql);

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
      .run(prescriptionsSql);

    res.status(200).json(result.recordset);

  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching prescription details',
      error: error.message
    });
  }
});

router.get('/appointment/getBookedSlots/:doctor_id/:clinic_id', async (req, res) => {
  const { doctor_id, clinic_id } = req.params;

  try {
    const result = await db.request()
      .input('operation', 'GET_MONTH_SLOTS')
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .run(appointmentsSql);

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
      .run(appointmentsSql);

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

    const result = await request.run(appointmentsSql);

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
            .input('clinic_id', item.clinic_id)
            .run(appointmentsSql);

          if (queueResult.recordset.length > 0) {
            const q = queueResult.recordset[0];

            // Override the SP's current_serving with the correct MAX-token value
            // so the patient's NOW circle matches the doctor screen and never
            // lags after a complete/skip/recall. Fall back to the SP value only
            // if our query returns null.
            const serving = await correctCurrentServing(item.appointment_id);

            queueData = {
              my_queue_number: q.my_queue_number,
              patients_ahead: q.patients_ahead,
              estimated_arrival_time: q.estimated_arrival_time,
              queue_started: q.queue_started,
              is_my_turn: q.is_my_turn,
              total_queue: q?.total_queue ?? null,
              current_serving: serving ?? q?.current_serving ?? null,
              queue_state: q?.status ?? null
            };
          }
        } catch (err) {
          // ignore queue error per item
        }
      }

      if ((item.status || '').toLowerCase() === 'skipped') {
        try {
          const arrivedRes = await db.request()
            .input('appointment_id', item.appointment_id)
            .query('SELECT is_arrived, arrived_at FROM appointments WHERE appointment_id = @appointment_id');
          const a = arrivedRes.recordset?.[0];
          queueData.is_arrived = a?.is_arrived ?? false;
          queueData.arrived_at = a?.arrived_at ?? null;
        } catch (err) {
          // ignore — not critical to the appointment list rendering
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



// All favorites for a patient, newest first.
router.get('/favoriteDoctors/:patient_id', async (req, res) => {
  try {
    const result = await db.request()
      .input('patient_id', sql.Int, req.params.patient_id)
      .query(`
        SELECT * FROM favorite_doctors
        WHERE patient_id = @patient_id AND is_favorite = 1
        ORDER BY created_at DESC
      `);
    res.status(200).json(result.recordset || []);
  } catch (error) {
    log.error('Error in get all favorites: ' + error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/favoriteDoctor/:patient_id/:doctor_id/:clinic_id', async (req, res) => {
  try {
    const { patient_id, doctor_id, clinic_id } = req.params;

    // Heart icon: is this doctor at this clinic a favorite?
    const result = await db.request()
      .input('patient_id', sql.Int, patient_id)
      .input('doctor_id', sql.Int, doctor_id)
      .input('clinic_id', sql.NVarChar(50), clinic_id === 'null' ? null : clinic_id)
      .query(`
        SELECT CASE WHEN EXISTS (
          SELECT 1 FROM favorite_doctors
          WHERE patient_id = @patient_id AND doctor_id = @doctor_id
            AND (clinic_id = @clinic_id OR (clinic_id IS NULL AND @clinic_id IS NULL))
            AND is_favorite = 1
        ) THEN 1 ELSE 0 END AS is_favorite
      `);

    res.status(200).json({
      is_favorite: result.recordset?.[0]?.is_favorite || 0
    });

  } catch (error) {
    log.error('Error in check favorite: ' + error.message);
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
      .input('appointment_id', sql.Int, appointment_id)
      .query('SELECT * FROM reviews WHERE appointment_id = @appointment_id');

    res.status(200).json(result.recordset || []);

  } catch (error) {
    log.error('Error in get review by appointment: ' + error.message);
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
      .run(notificationsSql);
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
      .run(notificationsSql);
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
      .run(notificationsSql);
    res.status(200).json({ success: true, message: 'All marked as read' });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error marking notifications',
      error: error.message,
    });
  }
});

// GET all reviews for doctor (optional clinic_id param)
router.get('/review/doctor/:doctor_id/:clinic_id', async (req, res) => {
  try {
    const { doctor_id, clinic_id } = req.params;

    // reviewed_by_name = the account that wrote it; patient_name = who the
    // appointment was for (the account holder, or one of their family members).
    // Reviews saved without a clinic show under every clinic of the doctor.
    const result = await db.request()
      .input('doctor_id', sql.Int, doctor_id)
      .input('clinic_id', sql.NVarChar(50), clinic_id)
      .query(`
        SELECT r.review_id, r.appointment_id, r.doctor_id, r.patient_id,
               p.name AS reviewed_by_name,
               -- self vs family comes from the appointment: patient and
               -- family-member ids are separate sequences and can be equal
               CASE WHEN a.user_type = 2 THEN fm.name ELSE p.name END AS patient_name,
               r.rating, r.comment, r.created_at
        FROM reviews r
        LEFT JOIN appointments a ON a.appointment_id = r.appointment_id
        LEFT JOIN Patients p ON p.patient_id = r.reviewed_by_user_id
        LEFT JOIN family_members fm ON fm.member_id = r.patient_id
        WHERE r.doctor_id = @doctor_id
          AND (@clinic_id IS NULL OR r.clinic_id = @clinic_id OR r.clinic_id IS NULL)
        ORDER BY r.created_at DESC
      `);

    res.status(200).json(result.recordset || []);

  } catch (error) {
    log.error('Error in get doctor reviews: ' + error.message);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


module.exports = router; 