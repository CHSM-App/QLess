// /doctor/insert — Live queue (next/start/pause/stop/skip/recall/sessions), doctor cancel, walk-in booking, and the stale-session sweep.

const express = require('express');
const db = require('../../../db');
const sql = require('mssql');
const admin = require('../../../fcm');
const cron = require('node-cron');
const log = require('../../../middleware/logger');
const { saveFamilyMember } = require('../../../familyMembers');

const {
  alreadyApplied,
  emitQueueUpdate,
  isStaleReplay,
  fetchCurrentServing,
  insertNotification,
  insertNotificationForToken,
  notifyTokensInBackground,
  sendPositionNotifications,
  sendProximityNotifications,
  formatApptDate,
  formatApptTime,
} = require('./shared');
const doctorLeaveSql = require('../../../queries/doctorLeave');
const notificationsSql = require('../../../queries/notifications');
const patientsSql = require('../../../queries/patients');
const appointmentsSql = require('../../../queries/appointments');

const router = express.Router();
require('../../../middleware/ownStaff').params(router); // URL ids (body ids: insert/index.js)

router.post('/appointment/queueNext', async (req, res) => {
  const { doctor_id, appointment_id, clinic_id } = req.body;

  if (!doctor_id) {
    return res.status(400).json({ success: false, message: 'doctor_id is required' });
  }
  if (!appointment_id) {
    return res.status(400).json({ success: false, message: 'appointment_id is required' });
  }

  try {
    if (await alreadyApplied(req, 'next')) return res.json({ success: true, message: 'Already applied' });
    const result = await db.request()
      .input('operation', 'NEXT_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .input('clinic_id', clinic_id || null)
      .run(appointmentsSql);

    const row = result.recordset?.[0] ?? {};

    if (row.success !== 1) {
      return res.json({
        success: false,
        message: row.message || 'Queue next failed'
      });
    }

    const token = row.token;
    const stale = isStaleReplay(req);

    log.debug('queueNext: next patient token present: ' + !!token);

    // 🔔 SEND NOTIFICATION TO NEXT PATIENT
    if (token && !stale) {
      const nextTitle = 'Your Turn Now';
      const nextBody = 'Doctor is ready to see you. Please proceed.';

      await insertNotificationForToken(token, nextTitle, nextBody, 'appointment', appointment_id);

      try {
        await admin.messaging().send({
          token: token,
          notification: { title: nextTitle, body: nextBody },
          data: { type: 'appointment', appointment_id: String(appointment_id) },
        });
      } catch (fcmErr) {
        log.error('FCM send failed for queueNext notification: ' + (fcmErr.code || fcmErr.message));
      }
    }

    if (!stale) {
      sendProximityNotifications(doctor_id, clinic_id);
      sendPositionNotifications(doctor_id, appointment_id);
    }
    const nextServing = await fetchCurrentServing(appointment_id);
    emitQueueUpdate(req, 'next', doctor_id, { current_serving: nextServing, clinic_id });

    return res.json({
      success: true,
      message: row.message ?? 'Queue next done'
    });

  } catch (error) {
    log.error('queueNext error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Queue next failed',
      error: error.message
    });
  }
});


// QUEUE START
router.post('/appointment/queueStart', async (req, res) => {
  const { doctor_id, queue_id } = req.body;

  if (!doctor_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id required'
    });
  }

  try {
    if (await alreadyApplied(req, 'queueStart')) return res.json({ success: true, message: 'Already applied' });
    const result = await db.request()
      .input('operation', 'QUEUE_START')
      .input('queue_id', queue_id)
      .input('doctor_id', doctor_id)
      .run(appointmentsSql);

    // QUEUE_START's SP returns the status row and the waiting-patient token
    // rows. Depending on the SP it may put them in ONE recordset (status first,
    // tokens after) or in TWO separate recordsets — exactly the gotcha
    // documented in queuePause below. node-mssql only exposes the first
    // recordset on `.recordset`, so the old `rows.slice(1)` silently found ZERO
    // tokens whenever the SP used the separate-recordset shape and no
    // "Doctor Arrived" push ever went out. Flatten every recordset and take all
    // token-bearing rows (the status row carries `success`, not a token).
    const allRows = (result.recordsets || [result.recordset || []]).flat();
    const statusRow = allRows.find(r => r && r.success != null) || {};

    /* if (statusRow.success !== 1) {
         return res.json({
           success: false,
           message: statusRow|| 'Queue start failed'
         });
       }*/


    const tokens = allRows
      .filter(r => r && r !== statusRow && r.token && String(r.token).trim() !== '')
      .map(r => r.token);

    if (tokens.length === 0 || isStaleReplay(req)) {
      emitQueueUpdate(req, 'queue_started', doctor_id, { queue_id });
      return res.json({
        success: true,
        message: 'Queue started, no patients to notify'
      });
    }

    let doctorName = 'your doctor';
    try {
      const ctx = await db.request()
        .input('operation', 'APPT_CONTEXT_QUEUE')
        .input('doctor_id', doctor_id)
        .input('queue_id', queue_id)
        .run(notificationsSql);
      doctorName = ctx.recordset?.[0]?.doctor_name || 'your doctor';
    } catch (e) { log.error('[queueStart] name lookup failed: ' + e.message); }
    const startTitle = 'Doctor Arrived';
    const startBody = `Dr. ${doctorName} has started the queue. Please be ready.`;

    // Inbox rows + push go out after the answer (A1); failures only log (B12).
    notifyTokensInBackground(tokens, startTitle, startBody, doctor_id, 'queueStart');

    sendProximityNotifications(doctor_id);
    emitQueueUpdate(req, 'queue_started', doctor_id, { queue_id });

    return res.json({
      success: true,
      message: 'Queue started and notifications sent',
      total_tokens: tokens.length
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Queue start failed',
      error: error.message
    });
  }
});


// QUEUE PAUSE
router.post('/appointment/queuePause', async (req, res) => {
  const { doctor_id, queue_id } = req.body;
  if (!doctor_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id required'
    });
  }

  try {
    if (await alreadyApplied(req, 'queuePause')) return res.json({ success: true, message: 'Already applied' });
    const result = await db.request()
      .input('operation', 'QUEUE_PAUSE')
      .input('queue_id', queue_id)
      .input('doctor_id', doctor_id)
      .run(appointmentsSql);

    // SP returns 2 separate result sets: [0] = status, [1] = token rows.
    // node-mssql's `result.recordset` is only the FIRST recordset, so tokens
    // live in `result.recordsets[1]`.
    const recordsets = result.recordsets || [];
    const statusRow = recordsets[0]?.[0] || {};
    const tokenRows = recordsets[1] || [];

    // ✅ CHECK SUCCESS
    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow.message || 'Queue pause failed'
      });
    }

    const tokens = tokenRows
      .map(r => r.token)
      .filter(t => t && t.trim() !== '');

    log.debug('queuePause: tokens count: ' + tokens.length);

    // 🔔 SEND NOTIFICATION
    if (tokens.length > 0 && !isStaleReplay(req)) {
      let doctorName = 'your doctor';
      try {
        const ctx = await db.request()
          .input('operation', 'APPT_CONTEXT_QUEUE')
          .input('doctor_id', doctor_id)
          .input('queue_id', queue_id)
          .run(notificationsSql);
        doctorName = ctx.recordset?.[0]?.doctor_name || 'your doctor';
      } catch (e) { log.error('[queuePause] name lookup failed: ' + e.message); }
      const pauseTitle = 'Queue Paused';
      const pauseBody = `Dr. ${doctorName} has paused the queue. Please wait.`;

      notifyTokensInBackground(tokens, pauseTitle, pauseBody, doctor_id, 'queuePause');

      emitQueueUpdate(req, 'queue_paused', doctor_id, { queue_id });
      return res.json({
        success: true,
        message: 'Queue paused and notifications sent',
        total_tokens: tokens.length
      });
    }

    // ✅ NO TOKENS CASE
    emitQueueUpdate(req, 'queue_paused', doctor_id, { queue_id });
    return res.json({
      success: true,
      message: 'Queue paused, no patients to notify'
    });

  } catch (error) {
    log.error('queuePause error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Queue pause failed',
      error: error.message
    });
  }
});



// QUEUE STOP
router.post('/appointment/queueStop', async (req, res) => {
  const { doctor_id, queue_id } = req.body;

  if (!doctor_id) {
    return res.status(400).json({ success: false, message: 'doctor_id required' });
  }

  try {
    if (await alreadyApplied(req, 'queueStop')) return res.json({ success: true, message: 'Already applied' });
    // Pre-fetch personalized context BEFORE the SP cancels everything.
    const detailsRes = await db.request()
      .input('operation', 'APPT_CONTEXT_QUEUE')
      .input('doctor_id', doctor_id)
      .input('queue_id', queue_id)
      .run(notificationsSql);

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

    // Skipped patients aren't part of the cancel context above, but they're
    // still left waiting when the queue closes — capture them (before the SP
    // mutates their status) so we can notify them too.
    const affectedIds = new Set(affectedAppts.map(a => a.patient_id));
    let skippedAppts = [];
    try {
      const skippedRes = await db.request()
        .input('queue_id', queue_id)
        .query(`
          SELECT a.patient_id, p.token AS owner_token, a.appointment_id
          FROM appointments a
          LEFT JOIN patients p ON a.user_type = 1 AND p.patient_id = a.patient_id
          WHERE a.queue_id = @queue_id AND LOWER(a.status) = 'skipped'
        `);
      skippedAppts = (skippedRes.recordset || [])
        .filter(r => r.patient_id && !affectedIds.has(r.patient_id));
    } catch (e) {
      log.error('[queueStop] skipped lookup failed: ' + e.message);
    }

    const result = await db.request()
      .input('operation', 'QUEUE_STOP')
      .input('queue_id', queue_id)
      .input('doctor_id', doctor_id)
      .run(appointmentsSql);

    const rows = result.recordset || [];
    const statusRow = rows[0] || {};

    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow.message || 'Queue stop failed'
      });
    }

    if (affectedAppts.length > 0) {
      const title = 'Appointment Cancelled';
      const tasks = affectedAppts.map((a) => {
        const when = a.time ? `your ${a.time} appointment` : 'your appointment';
        const body =
          `Dr. ${a.doctor_name} has stopped today's queue. ${when} has been cancelled. ` +
          `Tap to book again.`;
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
          }).catch(err => log.error('FCM err (queueStop): ' + err.message)),
        ),
      );
    }

    if (skippedAppts.length > 0) {
      const doctorName = affectedAppts[0]?.doctor_name || 'your doctor';
      const title = 'Queue Closed';
      const body =
        `Dr. ${doctorName} has closed today's queue. You were skipped earlier — ` +
        `please contact the clinic or book again.`;

      await Promise.all(skippedAppts.map(s =>
        insertNotification(s.patient_id, title, body, 'appointment', s.appointment_id),
      ));

      await Promise.all(skippedAppts
        .filter(s => s.owner_token && s.owner_token.trim() !== '')
        .map(s =>
          admin.messaging().send({
            token: s.owner_token,
            notification: { title, body },
            data: {
              type: 'appointment',
              action: 'cancelled',
              doctor_id: String(doctor_id),
              appointment_id: String(s.appointment_id),
            },
          }).catch(err => log.error('FCM err (queueStop skipped): ' + err.message)),
        ),
      );
      log.info('[queueStop] notified ' + skippedAppts.length + ' skipped patient(s)');
    }

    emitQueueUpdate(req, 'queue_stopped', doctor_id, { queue_id });
    return res.json({
      success: true,
      message: statusRow.message || 'Queue stopped',
      cancelled_notifications: affectedAppts.length,
      skipped_notifications: skippedAppts.length
    });

  } catch (error) {
    log.error('queueStop error: ' + error.message);
    return res.status(500).json({ success: false, message: 'Queue stop failed', error: error.message });
  }
});

// STOP/RESUME BOOKING — toggles new-booking acceptance for today's queue
// WITHOUT touching the queue itself. Existing waiting patients are left
// exactly as-is (no cancellation, no forced completion); use queueStop for
// that. Distinct from queue_status so a doctor can pause new patients from
// joining while still serving whoever is already in line.
router.post('/appointment/stopBooking', async (req, res) => {
  const { doctor_id, queue_id, booking_closed } = req.body;

  if (!doctor_id || !queue_id) {
    return res.status(400).json({ success: false, message: 'doctor_id and queue_id are required' });
  }

  try {
    const result = await db.request()
      .input('queue_id', queue_id)
      .input('doctor_id', doctor_id)
      .input('booking_closed', booking_closed ? 1 : 0)
      .query(`
        UPDATE doctor_queue
        SET booking_closed = @booking_closed
        WHERE queue_id = @queue_id AND doctor_id = @doctor_id
      `);

    if (result.rowsAffected?.[0] === 0) {
      return res.json({ success: false, message: 'Queue not found' });
    }

    emitQueueUpdate(req, 'booking_status_changed', doctor_id, { queue_id, booking_closed: !!booking_closed });

    return res.json({
      success: true,
      message: booking_closed ? 'New bookings stopped' : 'New bookings resumed',
      booking_closed: !!booking_closed,
    });

  } catch (error) {
    log.error('stopBooking error: ' + error.message);
    return res.status(500).json({ success: false, message: 'Stop booking failed', error: error.message });
  }
});

//QUEUE SKIP
router.post('/appointment/queueSkip', async (req, res) => {
  const { doctor_id, appointment_id, is_next } = req.body;

  if (!doctor_id) {
    return res.status(400).json({ success: false, message: 'doctor_id is required' });
  }

  if (!appointment_id) {
    return res.status(400).json({ success: false, message: 'appointment_id is required' });
  }

  try {
    if (await alreadyApplied(req, 'skip')) return res.json({ success: true, message: 'Already applied' });
    const result = await db.request()
      .input('operation', 'SKIP_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .input('is_next', is_next)
      .run(appointmentsSql);

    const row = result.recordset?.[0] ?? {};

    // ✅ CHECK SUCCESS
    if (row.success !== 1) {
      return res.json({
        success: false,
        message: row.message || 'Queue skip failed'
      });
    }

    const token = row.token;
    const stale = isStaleReplay(req);

    log.debug('queueSkip: skipped patient token present: ' + !!token);

    // 🔔 SEND ONLY TO SKIPPED PATIENT
    if (token && !stale) {
      const skipTitle = 'You were skipped';
      const skipBody = 'Doctor skipped your turn due to absence. Please contact clinic.';

      try {
        await insertNotificationForToken(token, skipTitle, skipBody, 'appointment', appointment_id);
      } catch (notifErr) {
        log.error('insertNotificationForToken failed: ' + notifErr.message);
      }

      try {
        await admin.messaging().send({
          token: token,
          notification: { title: skipTitle, body: skipBody },
          // appointment_id lets the killed-app FCM tap auto-open the detail
          // sheet for the skipped appointment so the patient can act on it.
          data: { type: 'appointment', appointment_id: String(appointment_id) },
        });
      } catch (fcmErr) {
        // Stale/unregistered tokens must not fail the skip operation
        log.error('FCM send failed for skip notification: ' + (fcmErr.code || fcmErr.message));
      }
    }

    if (!stale) {
      sendProximityNotifications(doctor_id);
      sendPositionNotifications(doctor_id, appointment_id);
    }
    const skipServing = await fetchCurrentServing(appointment_id);
    emitQueueUpdate(req, 'skip', doctor_id, { current_serving: skipServing });

    return res.json({
      success: true,
      message: row.message || 'Patient skipped and notified'
    });

  } catch (error) {
    log.error('queueSkip error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Queue skip failed',
      error: error.message
    });
  }
});


//QUEUE RECALL
router.post('/appointment/queueRecall', async (req, res) => {
  const { appointment_id, doctor_id } = req.body;

  // ✅ validation
  if (!appointment_id) {
    return res.status(400).json({
      success: false,
      message: 'appointment_id required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'RECALL_SESSION')
      .input('appointment_id', appointment_id)
      // RECALL_SESSION finds today's running queue by doctor; without it
      // every queue recall answered "Queue not started or already stopped".
      .input('doctor_id', doctor_id)
      .run(appointmentsSql);

    const row = result.recordset?.[0] ?? {};

    if (row.success === 1) {
      const recallServing = await fetchCurrentServing(appointment_id);
      emitQueueUpdate(req, 'recall', doctor_id, { current_serving: recallServing });
    }

    return res.json({
      success: row.success === 1,
      message: row.message ?? 'Patient recalled'
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Queue recall failed',
      error: error.message
    });
  }
});


router.post('/appointment/startSession', async (req, res) => {
  const { doctor_id, appointment_id } = req.body;

  // ✅ validation
  if (!doctor_id || !appointment_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id and appointment_id are required'
    });
  }

  try {
    if (await alreadyApplied(req, 'start')) return res.json({ success: true, message: 'Already applied' });
    const result = await db.request()
      .input('operation', 'START_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .run(appointmentsSql);

    const row = result.recordset?.[0] ?? {};

    if (row.success === 1) {
      const startServing = await fetchCurrentServing(appointment_id);
      emitQueueUpdate(req, 'session_started', doctor_id, { current_serving: startServing });
    }
    return res.json({
      success: row.success === 1,
      message: row.message ?? 'Session started'
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Start session failed',
      error: error.message
    });
  }
});



//END SESSION 
router.post('/appointment/endSession', async (req, res) => {
  const { doctor_id, appointment_id, clinic_id } = req.body;

  if (!doctor_id || !appointment_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id and appointment_id are required'
    });
  }

  try {
    if (await alreadyApplied(req, 'end')) return res.json({ success: true, message: 'Already applied' });
    const result = await db.request()
      .input('operation', 'END_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .input('clinic_id', clinic_id || null)
      .run(appointmentsSql);

    const allRows = (result.recordsets || [result.recordset || []]).flat();
    const statusRow = allRows.find(r => r && r.success != null) || {};

    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow.message || 'End session failed'
      });
    }

    // Practo-style queue notifications are purely position/ETA driven. The
    // patient who just moved up gets a single "Almost your turn" from
    // sendProximityNotifications — we deliberately DON'T send a separate fixed
    // "Be Ready (3rd in queue)" push, which only duplicated the proximity
    // 'near' stage for the same patient. Every ended consultation shifts each
    // waiting patient one slot closer, so re-scan proximity here.
    if (!isStaleReplay(req)) {
      sendProximityNotifications(doctor_id, clinic_id);
      sendPositionNotifications(doctor_id, appointment_id);
    }
    emitQueueUpdate(req, 'session_ended', doctor_id);

    return res.json({
      success: true,
      message: statusRow.message || 'Session ended'
    });

  } catch (error) {
    log.error('endSession error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'End session failed',
      error: error.message
    });
  }
});


// QUEUE PAUSE (EMERGENCY)
// Mirrors QUEUE_PAUSE convention: SP returns row[0] = status, rows[1..] = { token }
// for every still-waiting patient on this queue. Each remaining patient gets an
// "emergency pause" notification so they don't keep waiting in the dark.
router.post('/appointment/queuePauseEmergency/:queue_id', async (req, res) => {
  const { queue_id } = req.params;

  if (!queue_id) {
    return res.status(400).json({
      success: false,
      message: 'queue_id required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'QUEUE_PAUSE_EMERGENCY')
      .input('queue_id', queue_id)
      .run(appointmentsSql);

    // SP returns 2 separate result sets: [0] = status, [1] = token rows.
    // node-mssql's `result.recordset` is only the FIRST recordset, so tokens
    // live in `result.recordsets[1]`.
    const recordsets = result.recordsets || [];
    const statusRow = recordsets[0]?.[0] || {};
    const tokenRows = recordsets[1] || [];

    log.debug('[queuePauseEmergency] recordsets count: ' + recordsets.length);
    log.debug('[queuePauseEmergency] status row: ' + JSON.stringify(statusRow));
    log.debug('[queuePauseEmergency] token rows count: ' + tokenRows.length);

    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow.message || 'Queue pause failed'
      });
    }

    const tokens = tokenRows
      .map(r => r.token)
      .filter(t => t && t.trim() !== '');

    log.debug('[queuePauseEmergency] tokens extracted: ' + tokens.length);

    let emergencyDoctorId = null;
    let doctorName = 'your doctor';
    try {
      const dn = await db.request()
        .input('queue_id', queue_id)
        .query(`SELECT dq.doctor_id, d.name FROM doctor_queue dq
                JOIN doctor_login d ON d.doctor_id = dq.doctor_id
                WHERE dq.queue_id = @queue_id`);
      emergencyDoctorId = dn.recordset?.[0]?.doctor_id ?? null;
      doctorName = dn.recordset?.[0]?.name || 'your doctor';
    } catch (e) { log.error('[queuePauseEmergency] name lookup failed: ' + e.message); }

    if (tokens.length > 0) {
      const pauseTitle = 'Queue Paused (Emergency)';
      const pauseBody = `Dr. ${doctorName} has paused the queue due to an emergency. Please wait — we will notify you when it resumes.`;

      notifyTokensInBackground(tokens, pauseTitle, pauseBody, queue_id, 'queuePauseEmergency');

      emitQueueUpdate(req, 'queue_paused_emergency', emergencyDoctorId, { queue_id });
      return res.json({
        success: true,
        message: statusRow.message || 'Queue paused successfully',
        total_tokens: tokens.length
      });
    }

    emitQueueUpdate(req, 'queue_paused_emergency', emergencyDoctorId, { queue_id });
    return res.json({
      success: true,
      message: statusRow.message || 'Queue paused, no patients to notify'
    });

  } catch (error) {
    log.error('[queuePauseEmergency] error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Queue pause failed',
      error: error.message
    });
  }
});

// CANCEL SLOT APPOINTMENT BY DOCTOR
router.post('/appointment/cancelByDoctor', async (req, res) => {
  const { appointment_id, doctor_id } = req.body;

  if (!appointment_id || !doctor_id) {
    return res.status(400).json({
      success: false,
      message: 'appointment_id and doctor_id required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'CANCEL_BY_DOCTOR')
      .input('appointment_id', appointment_id)
      .input('doctor_id', doctor_id)
      .run(appointmentsSql);

    const row = result.recordset?.[0] || {};

    if (row.success !== 1) {
      return res.json({
        success: false,
        message: row.message || 'Cancel failed'
      });
    }

    // Cancelling a patient shifts everyone behind them up — re-scan proximity.
    sendProximityNotifications(doctor_id);
    emitQueueUpdate(req, 'cancel', doctor_id);

    return res.json({
      success: true,
      message: row.message || 'Slot appointment cancelled successfully'
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Cancel failed',
      error: error.message
    });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// WALK-IN PATIENT BOOK (Receptionist)
// Finds or creates a patient by mobile, then books the appointment.
// ─────────────────────────────────────────────────────────────────────────────
router.post('/walkInBook', async (req, res) => {
  const { name, mobile_no, doctor_id, clinic_id, appointment_date, start_time, slot_id, user_type, symptoms, gender_id, family_id, patient_id: existingPatientId } = req.body;

  if (!name || !mobile_no || !doctor_id || !appointment_date) {
    return res.status(400).json({ success: false, message: 'name, mobile_no, doctor_id, appointment_date required' });
  }
  if (String(name).trim().length > 100) {
    return res.status(400).json({ success: false, message: 'Name can be at most 100 characters.' });
  }

  try {
    // Offline replay (offline_queued_at set by the app): the original send may
    // have landed before its response was lost, so first check whether this
    // walk-in already exists — same doctor, date, name and mobile, not
    // cancelled — and return it instead of creating a second patient + booking.
    // Online walk-ins skip this check and behave exactly as before.
    if (req.body.offline_queued_at) {
      const dup = await db.request()
        .input('doctor_id', sql.Int, parseInt(doctor_id))
        .input('appointment_date', appointment_date)
        .input('name', String(name).trim())
        .input('mobile_no', String(mobile_no))
        .query(`
          SELECT TOP 1 a.appointment_id, a.patient_id
          FROM appointments a
          LEFT JOIN patients p ON a.user_type = 1 AND p.patient_id = a.patient_id
          LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
          WHERE a.doctor_id = @doctor_id
            AND a.appointment_date = @appointment_date
            AND LOWER(ISNULL(a.status, '')) <> 'cancelled'
            AND LTRIM(RTRIM(COALESCE(p.name, fm.name))) = @name
            AND COALESCE(p.mobile_no, fm.mobile_no) = @mobile_no
        `);
      const row = dup.recordset?.[0];
      if (row) {
        log.info(`walkInBook: replay matched existing appointment ${row.appointment_id} — skipped duplicate`);
        return res.json({ success: true, message: 'Walk-in already booked', patient_id: row.patient_id, appointment_id: row.appointment_id });
      }
    }

    let patient_id;

    if (family_id) {
      // Family member booking: insert into family_members, then book appointment under the
      // primary patient's id (family_id) with user_type=2.
      const famRes = await saveFamilyMember('Insert', {
        member_id: null,
        family_id: parseInt(family_id),
        name: String(name).trim(),
        Gender_id: gender_id ? parseInt(gender_id) : null,
        relation_id: null,
        DOB: null,
        mobile_no,
      });
      patient_id = famRes.recordset[0]?.member_id;
      log.info(`walkInBook family: family_id=${family_id} member_id=${patient_id}`);
      if (!patient_id) throw new Error('Failed to create family member record');
    } else if (existingPatientId) {
      // Existing patient returning — use their patient_id directly.
      patient_id = parseInt(existingPatientId);
    } else {
      // New first-time walk-in — create a shadow profile in patients table.
      const insertRes = await db.request()
        .input('operation', 'Insert')
        .input('patient_id', null)
        .input('name', String(name).trim())
        .input('mobile_no', mobile_no)
        .input('email', null)
        .input('Address', null)
        .input('gender_id', gender_id ? parseInt(gender_id) : null)
        .input('DOB', null)
        .input('blood_group_id', null)
        .input('weight', null)
        .run(patientsSql);
      patient_id = insertRes.recordset[0]?.patient_id;
      if (!patient_id) throw new Error('Failed to create patient profile');
    }

    // Step 2: Check doctor leave
    const blockRes = await db.request()
      .input('operation', 'IS_BLOCKED')
      .input('doctor_id', doctor_id)
      .input('from_date', appointment_date)
      .run(doctorLeaveSql);

    if (blockRes.recordset?.[0]?.blocked === 1) {
      return res.json({ success: false, message: 'Doctor is on leave on this date. Please pick another date.' });
    }

    // Step 3: Book appointment
    const bookRes = await db.request()
      .input('operation', 'BOOK')
      .input('user_type', user_type || 1)
      .input('doctor_id', doctor_id)
      .input('patient_id', patient_id)
      .input('appointment_date', appointment_date)
      .input('start_time', start_time || null)
      .input('slot_id', slot_id || null)
      .input('symptoms', symptoms || '')
      .input('clinic_id', clinic_id || null)
      .run(appointmentsSql);

    const booked = bookRes.recordset[0].success === 1;
    log.info(`walkInBook: patient_id=${patient_id} user_type=${user_type} family_id=${family_id || null} booked=${booked} msg=${bookRes.recordset[0].message}`);
    if (booked) emitQueueUpdate(req, 'booked', doctor_id);

    // The new appointment's id goes back to the app so an offline walk-in's
    // placeholder id can be swapped for it (queued prescription / queue ops).
    // Queue running and nobody in progress or waiting → start this walk-in
    // straight away so the doctor doesn't have to press Start on them. The app
    // opens the prescription for started_appointment_id. Not on offline replay:
    // the doctor's own queued start/next actions replay right after.
    let appointment_id = null;
    let started_appointment_id = null;
    if (booked) {
      try {
        const appt = await db.request()
          .input('doctor_id', sql.Int, parseInt(doctor_id))
          .input('patient_id', sql.Int, patient_id)
          .input('user_type', sql.Int, parseInt(user_type || 1))
          .input('appointment_date', appointment_date)
          .query(`
            SELECT TOP 1 a.appointment_id,
              CASE WHEN a.booking_type = 1 AND dq.queue_status = 1 AND NOT EXISTS (
                SELECT 1 FROM appointments o
                WHERE o.queue_id = a.queue_id AND o.appointment_id <> a.appointment_id
                  AND o.status IN ('booked', 'in_progress'))
              THEN 1 ELSE 0 END AS idle
            FROM appointments a
            LEFT JOIN doctor_queue dq ON dq.queue_id = a.queue_id
            WHERE a.doctor_id = @doctor_id AND a.patient_id = @patient_id
              AND a.user_type = @user_type AND a.appointment_date = @appointment_date
              AND a.status = 'booked'
            ORDER BY a.appointment_id DESC
          `);
        const row = appt.recordset?.[0];
        appointment_id = row?.appointment_id ?? null;
        if (appointment_id && row.idle === 1 && !req.body.offline_queued_at) {
          const start = await db.request()
            .input('operation', 'START_SESSION')
            .input('doctor_id', doctor_id)
            .input('appointment_id', appointment_id)
            .run(appointmentsSql);
          if (start.recordset?.[0]?.success === 1) {
            started_appointment_id = appointment_id;
            const serving = await fetchCurrentServing(appointment_id);
            emitQueueUpdate(req, 'session_started', doctor_id, { current_serving: serving });
          }
        }
      } catch (e) {
        // Booking already succeeded; the doctor can still start manually.
        log.error('walkInBook auto-start failed: ' + e.message);
      }
    }

    return res.json({
      success: booked,
      message: bookRes.recordset[0].message,
      patient_id,
      appointment_id,
      started_appointment_id,
    });

  } catch (error) {
    return res.status(500).json({ success: false, message: 'Walk-in booking failed', error: error.message });
  }
});





// ─────────────────────────────────────────────────────────────────────────────
// AUTO-CLOSE STALE SESSIONS
// A queue/slot session a doctor forgets to close at end of day stays "open"
// (doctor_queue.queue_status <> 3 with queue_date < today). GET_TODAY_QUEUE then
// keeps returning it, so it lingers on the doctor's Home / Patient List the next
// day, and its booked/skipped patients are never told their visit lapsed.
//
// This sweep, for every stale session:
//   1. closes each stale queue by reusing the proven QUEUE_STOP flow (same as the
//      manual Close button at /appointment/queueStop), and
//   2. cancels any remaining past-dated pending appointment (slot bookings +
//      stragglers) via CANCEL_BY_DOCTOR,
// then notifies each affected patient that they missed their appointment.
//
// Idempotent: only still-pending rows are selected, so a second run is a no-op —
// safe to fire from the nightly cron, on startup, AND lazily on getTodayQueue.
// ─────────────────────────────────────────────────────────────────────────────

// Only notify about a no-show that lapsed recently. The nightly cron always sees
// yesterday's data (so this is always true there), but a first-run / startup
// catch-up can hit a backlog of weeks-old sessions — we still cancel+close those
// for cleanup, but pushing "you missed your 15 May visit" today would be spam.
const NOTIFY_MAX_AGE_DAYS = 2;
function isWithinNotifyWindow(rawDate) {
  if (!rawDate) return false;
  const d = new Date(rawDate);
  if (isNaN(d.getTime())) return false;
  const ageMs = Date.now() - d.getTime();
  return ageMs <= NOTIFY_MAX_AGE_DAYS * 24 * 60 * 60 * 1000;
}

// Shared "you missed your visit" notification (inbox row + FCM). Mirrors the
// data payload shape used by queueStop so the killed-app tap behaves the same.
// Silently skips stale backlog (see NOTIFY_MAX_AGE_DAYS) — cancellation already
// happened at the call site regardless.
async function notifyMissedAppointment(doctor_id, a) {
  if (!isWithinNotifyWindow(a.rawDate)) return;

  const title = 'Appointment Closed';
  const when = a.date ? ` on ${a.date}` : '';
  const body =
    `You missed your appointment with Dr. ${a.doctor_name}${when}. ` +
    `It has been closed. Tap to book again.`;

  await insertNotification(a.patient_id, title, body, 'appointment', a.appointment_id);

  if (a.token && a.token.trim() !== '') {
    await admin.messaging().send({
      token: a.token,
      notification: { title, body },
      data: {
        type: 'appointment',
        action: 'cancelled',
        doctor_id: String(doctor_id),
        appointment_id: String(a.appointment_id),
      },
    }).catch(err => log.error('FCM err (staleSweep): ' + (err.code || err.message)));
  }
}

// Close one stale queue — mirrors the /appointment/queueStop handler: capture
// affected (pending + skipped) patients BEFORE the SP mutates them, run QUEUE_STOP,
// then notify with no-show wording.
async function closeOneStaleQueue(doctor_id, queue_id) {
  const detailsRes = await db.request()
    .input('operation', 'APPT_CONTEXT_QUEUE')
    .input('doctor_id', doctor_id)
    .input('queue_id', queue_id)
    .run(notificationsSql);

  const affected = [];
  for (const row of (detailsRes.recordset || [])) {
    if (!row.owner_id) continue;
    affected.push({
      patient_id: row.owner_id,
      token: row.owner_token,
      doctor_name: row.doctor_name || 'your doctor',
      date: formatApptDate(row.appointment_date),
      rawDate: row.appointment_date,
      appointment_id: row.appointment_id,
    });
  }

  // Skipped patients aren't in the cancel context but are still left waiting —
  // capture them before QUEUE_STOP flips their status.
  const affectedIds = new Set(affected.map(a => a.patient_id));
  const doctorName = affected[0]?.doctor_name || 'your doctor';
  try {
    const skippedRes = await db.request()
      .input('queue_id', queue_id)
      .query(`
        SELECT a.patient_id, p.token AS owner_token, a.appointment_id,
               a.appointment_date
        FROM appointments a
        LEFT JOIN patients p ON a.user_type = 1 AND p.patient_id = a.patient_id
        WHERE a.queue_id = @queue_id AND LOWER(a.status) = 'skipped'
      `);
    for (const r of (skippedRes.recordset || [])) {
      if (!r.patient_id || affectedIds.has(r.patient_id)) continue;
      affected.push({
        patient_id: r.patient_id,
        token: r.owner_token,
        doctor_name: doctorName,
        date: formatApptDate(r.appointment_date),
        rawDate: r.appointment_date,
        appointment_id: r.appointment_id,
      });
    }
  } catch (e) {
    log.error('[staleSweep] skipped lookup failed: ' + e.message);
  }

  const result = await db.request()
    .input('operation', 'QUEUE_STOP')
    .input('queue_id', queue_id)
    .input('doctor_id', doctor_id)
    .run(appointmentsSql);
  const statusRow = (result.recordset || [])[0] || {};
  if (statusRow.success !== 1) {
    throw new Error(statusRow.message || 'QUEUE_STOP failed');
  }

  await Promise.all(affected.map(a => notifyMissedAppointment(doctor_id, a)));
  return affected.length;
}

// Cancel any past-dated appointment still pending (slot bookings + stragglers not
// tied to a queue closed above). Queue rows are already 'cancelled' by QUEUE_STOP,
// so this picks up only what's left — keeping the sweep idempotent.
async function cancelStalePendingAppointments() {
  const res = await db.request().query(`
    SELECT a.appointment_id, a.doctor_id, a.patient_id, a.appointment_date,
           p.token AS owner_token, d.name AS doctor_name
    FROM appointments a
    LEFT JOIN patients p     ON a.user_type = 1 AND p.patient_id = a.patient_id
    LEFT JOIN doctor_login d ON d.doctor_id = a.doctor_id
    WHERE a.appointment_date < CAST(GETDATE() AS DATE)
      AND LOWER(a.status) IN ('booked', 'in_progress', 'skipped')
  `);

  let count = 0;
  for (const row of (res.recordset || [])) {
    try {
      const r = await db.request()
        .input('operation', 'CANCEL_BY_DOCTOR')
        .input('appointment_id', row.appointment_id)
        .input('doctor_id', row.doctor_id)
        .run(appointmentsSql);
      if ((r.recordset?.[0]?.success) !== 1) continue;
      count++;
      await notifyMissedAppointment(row.doctor_id, {
        patient_id: row.patient_id,
        token: row.owner_token,
        doctor_name: row.doctor_name || 'your doctor',
        date: formatApptDate(row.appointment_date),
        rawDate: row.appointment_date,
        appointment_id: row.appointment_id,
      });
    } catch (e) {
      log.error(`[staleSweep] cancel appt ${row.appointment_id} failed: ${e.message}`);
    }
  }
  return count;
}

// In-process guard so the nightly cron and a lazy getTodayQueue call can't run the
// sweep concurrently (would double-notify on a race).
let _staleSweepRunning = false;
async function closeStaleSessions() {
  if (_staleSweepRunning) return { skipped: true };
  _staleSweepRunning = true;
  let queuesClosed = 0;
  let slotsCancelled;
  try {
    const staleQ = await db.request().query(`
      SELECT queue_id, doctor_id FROM doctor_queue
      WHERE queue_date < CAST(GETDATE() AS DATE) AND queue_status <> 3
    `);

    for (const q of (staleQ.recordset || [])) {
      try {
        await closeOneStaleQueue(q.doctor_id, q.queue_id);
        queuesClosed++;
      } catch (e) {
        log.error(`[staleSweep] queue ${q.queue_id} failed: ${e.message}`);
      }
    }

    slotsCancelled = await cancelStalePendingAppointments();

    if (queuesClosed > 0 || slotsCancelled > 0) {
      log.info(`[staleSweep] closed ${queuesClosed} stale queue(s), cancelled ${slotsCancelled} stale appt(s)`);
    }
    return { queuesClosed, slotsCancelled };
  } catch (e) {
    log.error('[staleSweep] failed: ' + e.message);
    return { error: e.message };
  } finally {
    _staleSweepRunning = false;
  }
}

// Nightly at 00:05 IST → a previous-day session is auto-closed as the new day starts.
cron.schedule('5 0 * * *', () => { closeStaleSessions(); },
  { timezone: 'Asia/Kolkata' });

// Catch up once on startup — covers a server/IIS recycle that straddled midnight
// and missed the cron. Deferred so it never blocks the listen() call.
// Not in tests: it would fire into the mock DB after the suite has finished.
if (process.env.NODE_ENV !== 'test') {
  setTimeout(() => { closeStaleSessions(); }, 5000);
}

module.exports = router;
module.exports.closeStaleSessions = closeStaleSessions;
