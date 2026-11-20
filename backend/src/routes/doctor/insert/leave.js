// /doctor/insert — Doctor leave: add, list, cancel.

const express = require('express');
const db = require('../../../db');
const admin = require('../../../fcm');
const log = require('../../../middleware/logger');

const {
  insertNotification,
  formatApptDate,
  formatApptTime,
} = require('./shared');

const router = express.Router();

// ──────────────────────────────────────────────────────────────────────────
//  DOCTOR LEAVE / SUTTI  (date-range unavailability — industry "Mark
//  Unavailable" pattern). Cancels every future booked/in_progress
//  appointment in the range and FCM-notifies the affected patients.
// ──────────────────────────────────────────────────────────────────────────
router.post('/addDoctorLeave', async (req, res) => {
  const { doctor_id, from_date, to_date, reason, force, clinic_id } = req.body;

  if (!doctor_id || !from_date || !to_date) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id, from_date and to_date are required',
    });
  }
  if (from_date > to_date) {
    return res.status(400).json({
      success: false,
      message: 'from_date cannot be after to_date',
    });
  }

  try {
    // PASS 1 — how many future appts will be cancelled? Gate behind `force`
    // (same UX as saveDoctorSchedule conflict gate).
    const countRes = await db.request()
      .input('operation', 'COUNT_AFFECTED')
      .input('doctor_id', doctor_id)
      .input('from_date', from_date)
      .input('to_date', to_date)
      .input('clinic_id', clinic_id || null)
      .execute('sp_doctor_leave');

    const affected = countRes.recordset?.[0]?.cnt ?? 0;

    if (affected > 0 && !force) {
      return res.status(409).json({
        success: false,
        message: 'Appointments exist in this date range. Confirm before applying leave.',
        affected_appointments: affected,
      });
    }

    // PASS 2 — record the leave
    const addRes = await db.request()
      .input('operation', 'ADD_LEAVE')
      .input('doctor_id', doctor_id)
      .input('from_date', from_date)
      .input('to_date', to_date)
      .input('reason', reason ?? null)
      .input('clinic_id', clinic_id || null)
      .execute('sp_doctor_leave');

    const row = addRes.recordset?.[0] ?? {};
    if (row.error) {
      return res.status(400).json({
        success: false,
        message: row.error === 'PAST_DATE'
          ? 'Leave start date is in the past'
          : 'Invalid leave date range',
      });
    }
    const leave_id = row.leave_id;

    // Pre-fetch personalized context BEFORE the SP changes statuses, so each
    // patient sees their own doctor + date in the notification.
    const detailsRes = await db.request()
      .input('operation', 'APPT_CONTEXT_DOCTOR_RANGE')
      .input('doctor_id', doctor_id)
      .input('from_date', from_date)
      .input('to_date', to_date)
      .execute('sp_notification');

    const affectedAppts = [];
    for (const row of (detailsRes.recordset || [])) {
      if (!row.owner_id) continue;
      affectedAppts.push({
        patient_id: row.owner_id,
        token: row.owner_token,
        doctor_name: row.doctor_name || 'your doctor',
        date: formatApptDate(row.appointment_date),
        time: formatApptTime(row.start_time),
        appointment_id: row.appointment_id,
      });
    }

    // PASS 3 — cancel future appts in range
    await db.request()
      .input('operation', 'APPLY_LEAVE_CANCEL')
      .input('doctor_id', doctor_id)
      .input('from_date', from_date)
      .input('to_date', to_date)
      .execute('sp_doctor_leave');

    // PASS 3.5 — normalize status to 'CancleD' so the patient app shows
    // "Cancelled by Doctor" (the leave SP otherwise sets generic 'cancelled'
    // which looks the same as a patient self-cancel).
    if (affectedAppts.length > 0) {
      await Promise.all(affectedAppts.map(a =>
        db.request()
          .input('operation', 'MARK_APPT_DOCTOR_CANCELLED')
          .input('appointment_id', a.appointment_id)
          .execute('sp_appointment')
          .catch(err =>
            log.error('status normalize err: ' + a.appointment_id + ' ' + err.message),
          ),
      ));
    }

    if (affectedAppts.length > 0) {
      const title = 'Appointment Cancelled';
      const tasks = affectedAppts.map((a) => {
        const when = a.date && a.time ? `${a.date} at ${a.time}`
          : a.date ? a.date
            : a.time ? `at ${a.time}`
              : '';
        const body =
          `Dr. ${a.doctor_name} is unavailable${when ? ' on ' + when : ''}. ` +
          `Your appointment has been cancelled. Tap to book again.`;
        return { ...a, title, body };
      });

      await Promise.all(tasks.map(t =>
        insertNotification(t.patient_id, t.title, t.body, 'appointment', t.appointment_id),
      ));

      await Promise.all(tasks
        .filter(t => t.token && t.token.trim() !== '')
        .map(t =>
          admin.messaging().send({
            token: t.token,
            notification: { title: t.title, body: t.body },
            data: {
              type: 'appointment',
              action: 'cancelled',
              doctor_id: String(doctor_id),
              appointment_id: String(t.appointment_id),
            },
          }).catch(err => log.error('FCM err (addDoctorLeave): ' + err.message)),
        ),
      );
    }

    return res.status(200).json({
      success: true,
      message: 'Leave applied successfully',
      leave_id,
      cancelled_appointments: affectedAppts.length,
    });

  } catch (error) {
    log.error('addDoctorLeave error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Error applying leave',
      error: error.message,
    });
  }
});

router.get('/doctorLeaves/:doctor_id/:clinic_id?', async (req, res) => {
  const { doctor_id, clinic_id } = req.params;
  try {
    const result = await db.request()
      .input('operation', 'LIST_LEAVE')
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_doctor_leave');

    res.status(200).json(result.recordset || []);
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching leaves',
      error: error.message,
    });
  }
});

router.post('/cancelDoctorLeave', async (req, res) => {
  const { doctor_id, leave_id, clinic_id } = req.body;

  if (!doctor_id || !leave_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id and leave_id are required',
    });
  }

  try {
    await db.request()
      .input('operation', 'CANCEL_LEAVE')
      .input('doctor_id', doctor_id)
      .input('leave_id', leave_id)
      .input('clinic_id', clinic_id || null)
      .execute('sp_doctor_leave');

    return res.status(200).json({
      success: true,
      message: 'Leave cancelled. Note: appointments already cancelled are not auto-restored.',
    });
  } catch (error) {
    log.error('cancelDoctorLeave error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Error cancelling leave',
      error: error.message,
    });
  }
});

module.exports = router;
