var express = require('express');
var router = express.Router();
var db = require('../db'); // go from admin/ to routes/
const sql = require("mssql");
const multer = require("multer");
const path = require("path");
const fs = require("fs-extra");
const admin = require("firebase-admin");
const cron = require('node-cron');
const log = require('../middleware/logger');

// Helper — emits a queue_update event to all sockets in clinic_<doctor_id> room.
// req.app.get('io') is available because app.set('io', io) is called in app.js.
function emitQueueUpdate(req, event, doctor_id, extra = {}) {
  const io = req.app.get('io');
  if (io && doctor_id) io.to('clinic_' + doctor_id).emit('queue_update', { event, doctor_id, ...extra });
}

// Returns the furthest queue_number the active queue has reached — MAX among
// in_progress and completed only. Skipped patients are handled outside the
// main queue and must not affect this value. When a skipped patient is
// recalled (skipped → in_progress), completed tokens still dominate the MAX
// (e.g. recalled token 2 after token 4 was completed → MAX = 4 ✓).
async function fetchCurrentServing(appointment_id) {
  try {
    const res = await db.request()
      .input('appointment_id', sql.Int, parseInt(appointment_id))
      .query(`
        SELECT MAX(a.queue_number) AS current_serving
        FROM   appointments a
        WHERE  a.queue_id = (SELECT queue_id FROM appointments WHERE appointment_id = @appointment_id)
          AND  a.status   IN ('in_progress', 'completed')
      `);
    return res.recordset[0]?.current_serving ?? null;
  } catch (_) {
    return null;
  }
}

if (!admin.apps.length) {
  const serviceAccount = require("../ServiceAccountKey.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// ── Notifications inbox helpers ─────────────────────────────────────────────
// Every FCM push is mirrored as a row in `notifications` via sp_notification
// so the patient's in-app Notifications screen has a persistent history.
// FCM alone is fire-and-forget — closed-app messages otherwise vanish.
async function insertNotification(patient_id, title, body, type, ref_id = null) {
  if (!patient_id || !title || !body || !type) return { success: 0 };
  try {
    const r = await db.request()
      .input('operation', 'INSERT')
      .input('patient_id', patient_id)
      .input('title', title)
      .input('body', body)
      .input('type', type)
      .input('ref_id', ref_id != null ? String(ref_id) : null)
      .execute('sp_notification');
    return r.recordset?.[0] ?? { success: 1 };
  } catch (err) {
    log.error('insertNotification failed: ' + err.message);
    return { success: 0, message: err.message };
  }
}

// Family-member appointments share the family head's FCM token, so the head's
// `patients.patient_id` is the right inbox owner in both cases.
async function insertNotificationForToken(token, title, body, type, ref_id = null) {
  if (!token) return;
  try {
    const r = await db.request()
      .input('token', token)
      .query('SELECT TOP 1 patient_id FROM patients WHERE token = @token');
    const patient_id = r.recordset?.[0]?.patient_id;
    if (!patient_id) return;
    await insertNotification(patient_id, title, body, type, ref_id);
  } catch (err) {
    log.error('insertNotificationForToken failed: ' + err.message);
  }
}

// Idempotency check for proximity notifications. As the queue moves, the same
// patient would cross the same threshold across multiple endSession events —
// we send the "30 min" / "10 min" notification ONCE per stage per appointment.
// ref_id is namespaced as "<appointment_id>:<stage>" to allow one row per stage
// without conflicting with single-stage notifications used elsewhere.
async function hasNotificationBeenSent(patient_id, type, ref_id) {
  if (!patient_id || !type || !ref_id) return false;
  try {
    const r = await db.request()
      .input('patient_id', patient_id)
      .input('type', type)
      .input('ref_id', String(ref_id))
      .query(`SELECT TOP 1 1 AS hit FROM notifications
              WHERE patient_id = @patient_id
                AND type = @type
                AND ref_id = @ref_id`);
    return (r.recordset?.[0]?.hit === 1);
  } catch (err) {
    log.error('hasNotificationBeenSent failed: ' + err.message);
    return false;
  }
}

// Proximity notifications — fired on every queue movement (queueStart,
// endSession, queueSkip, cancelByDoctor). For each waiting patient, the SP
// returns estimated minutes-to-turn based on (position-1) * avg consultation
// time. We send:
//   Stage 2 ("queue_far",  25–35 min away) — "Head to the clinic now"
//   Stage 3 ("queue_near",  5–15 min away) — "Almost your turn"
// Stage 4 ("Be Ready", 3rd in queue) and Stage 5 ("Your Turn Now") are already
// covered by endSession's existing rows[1] token and queueNext respectively.
//
// REQUIRED SP OPERATION — sp_appointment @operation = 'QUEUE_PROXIMITY_LIST':
//   IN : @doctor_id
//   OUT (one row per still-waiting appt today for this doctor, EXCLUDING
//        positions 1–3 since those are covered by existing notifications):
//     appointment_id        INT
//     owner_id              INT     -- family head's patients.patient_id
//     owner_token           NVARCHAR(MAX)
//     doctor_name           NVARCHAR
//     est_minutes_to_turn   INT     -- (position - 1) * avg_consultation_minutes
//
// Fire-and-forget — failures here must not break the calling endpoint.
async function sendProximityNotifications(doctor_id) {
  if (!doctor_id) return;
  try {
    const r = await db.request()
      .input('operation', 'QUEUE_PROXIMITY_LIST')
      .input('doctor_id', doctor_id)
      .execute('sp_appointment');

    const rows = r.recordset || [];
    if (rows.length === 0) return;

    await Promise.all(rows.map(async (row) => {
      const minutes = row.est_minutes_to_turn;
      const patient_id = row.owner_id;
      const token = row.owner_token;
      const aptId = row.appointment_id;
      const doctor = row.doctor_name || 'your doctor';
      if (!patient_id || !aptId || minutes == null) return;

      let stage = null, title = null, body = null;
      if (minutes >= 25 && minutes <= 35) {
        stage = 'queue_far';
        title = 'Your turn is approaching';
        body = `Your turn with Dr. ${doctor} is in about ${minutes} minutes. Please head to the clinic now.`;
      } else if (minutes >= 5 && minutes <= 15) {
        stage = 'queue_near';
        title = 'Almost your turn';
        body = `Your turn with Dr. ${doctor} is in about ${minutes} minutes. Please be at the clinic.`;
      } else {
        return;
      }

      const refId = `${aptId}:${stage}`;
      if (await hasNotificationBeenSent(patient_id, 'queue', refId)) return;

      await insertNotification(patient_id, title, body, 'queue', refId);

      if (token && token.trim() !== '') {
        await admin.messaging().send({
          token,
          notification: { title, body },
          data: {
            type: 'queue',
            stage,
            doctor_id: String(doctor_id),
            appointment_id: String(aptId),
          },
        }).catch(err =>
          log.error('FCM err (proximity): ' + (err.code || err.message)),
        );
      }
    }));
  } catch (err) {
    log.error('sendProximityNotifications failed: ' + err.message);
  }
}

// Format helpers for human-readable notification bodies. mssql returns TIME
// as a Date pinned to 1970-01-01, so we extract just the time portion.
function formatApptDate(d) {
  if (!d) return '';
  const dt = new Date(d);
  if (isNaN(dt.getTime())) return '';
  return dt.toLocaleDateString('en-IN', {
    day: 'numeric', month: 'short', year: 'numeric',
  });
}

function formatApptTime(t) {
  if (!t) return '';
  let h, m;
  if (t instanceof Date) {
    // node-mssql returns a TIME column as a Date pinned to 1970-01-01 whose
    // LOCAL wall-clock equals the stored value (tedious builds it from the
    // server TZ), so read it back with getHours/getMinutes — NOT getUTC* and
    // NOT String()+split('T') (a Date's toString has no 'T', yielding NaN).
    if (isNaN(t.getTime())) return '';
    h = t.getHours();
    m = t.getMinutes();
  } else {
    let s = String(t);
    if (s.includes('T')) s = s.split('T')[1].split('.')[0];
    const parts = s.split(':');
    h = parseInt(parts[0], 10);
    m = parseInt(parts[1], 10);
  }
  if (isNaN(h)) return '';
  const mm = String(isNaN(m) ? 0 : m).padStart(2, '0');
  const ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12 || 12;
  return `${h}:${mm} ${ampm}`;
}

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

router.post('/insertMedicine', async (req, res) => {
  const {
    doctor_id,
    medicine_name,
    medicine_type_id
  } = req.body;

  try {
    const request = db.request();

    request.input('operation', 'Insert');
    request.input('doctor_id', doctor_id);
    request.input('medicine_name', medicine_name);
    request.input('medicine_type_id', medicine_type_id);

    const result = await request.execute('sp_Medicine_Master');

    const message = result.recordset?.[0]?.Message || 'Medicine inserted successfully';
    const isDuplicate = message.toLowerCase().includes('already exists');

    res.status(isDuplicate ? 409 : 200).json({
      success: isDuplicate ? 0 : 1,
      message,
      data: result.recordset,
    });

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to insert medicine. ${error}`,
    });
  }
});


router.post('/addQueueStartTime/', async (req, res) => {
  const {
    doctor_id,
    q_start_before
  } = req.body;

  try {
    const request = db.request();

    request.input('operation', 'Insert_Q_StartTime'); // SP operation
    request.input('doctor_id', doctor_id);
    request.input('q_start_before', q_start_before);

    // Execute stored procedure
    const result = await request.execute('sp_doctor_login');

    res.status(200).json({
      success: 1,
      message: 'Time inserted successfully',
      data: result.recordset,
    });

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to insert Time ${error}`,
    });
  }
});


router.post('/saveDoctorSchedule', async (req, res) => {
  const { doctor_id, schedule, force } = req.body;
  const action = req.body.action === 'reschedule' ? 'reschedule' : 'cancel';

  if (!doctor_id || !Array.isArray(schedule)) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id and schedule (array) required'
    });
  }
  log.debug('saveDoctorSchedule payload: ' + JSON.stringify({
    doctor_id,
    force: !!force,
    days: schedule.map(d => ({
      day: d.day,
      is_enabled: d.is_enabled,
      slot_ids: (d.slots || []).map(s => s.slot_id),
    })),
  }));

  try {

    const toMin = (t) => {
      const [h, m] = String(t || '').split(':');
      return (parseInt(h, 10) || 0) * 60 + (parseInt(m, 10) || 0);
    };
    for (const day of schedule) {
      if (day.is_enabled !== 1) continue;
      const slots = (day.slots || [])
        .map(s => ({ s: toMin(s.start_time), e: toMin(s.end_time) }))
        .sort((a, b) => a.s - b.s);
      for (let i = 0; i < slots.length; i++) {
        if (slots[i].e <= slots[i].s) {
          return res.status(400).json({
            success: false,
            message: `${day.day}: a slot's end time must be after its start time.`,
          });
        }
        if (i > 0 && slots[i].s < slots[i - 1].e) {
          return res.status(400).json({
            success: false,
            message: `${day.day}: time slots overlap. Please fix the timings.`,
          });
        }
      }
    }

    const conflicts = [];     // FUTURE appts (cancel/reschedule gate)
    const todayBlocked = [];  // TODAY's live bookings on a slot being removed/retimed
    // Current schedule (slot_id -> timing) to detect timing changes.
    const cur = await db.request()
      .input('operation', 'GET')
      .input('doctor_id', doctor_id)
      .execute('sp_doctor_schedule');
    const curTiming = {};
    for (const r of (cur.recordset || [])) {
      if (r.slot_id != null) {
        curTiming[r.slot_id] = {
          start: String(r.start_time || '').slice(0, 5),
          end: String(r.end_time || '').slice(0, 5),
        };
      }
    }
    const norm = (t) => String(t || '').slice(0, 5);
    const todayCount = async (slot_id) => {
      const r = await db.request()
        .input('slot_id', slot_id)
        .execute('sp_slot_today_count');
      return r.recordset?.[0]?.cnt ?? 0;
    };

    for (const day of schedule) {
      const existing = await db.request()
        .input('operation', 'GET_DAY_SLOT_IDS')
        .input('doctor_id', doctor_id)
        .input('day_of_week', day.day)
        .execute('sp_doctor_schedule');

      const existingIds = (existing.recordset || []).map(r => r.slot_id);
      const incomingIds = (day.slots || [])
        .map(s => s.slot_id)
        .filter(id => id != null);

      const toDelete = existingIds.filter(id => !incomingIds.includes(id));

      // also: if day is being disabled entirely, every existing slot is gone
      const disablingDay = day.is_enabled !== 1;
      const removedSlotIds = disablingDay ? existingIds : toDelete;

      // (a) Removed slots: future -> cancel/reschedule gate;
      //     TODAY's live bookings -> hard block (would be orphaned).
      for (const slot_id of removedSlotIds) {
        if ((await todayCount(slot_id)) > 0) todayBlocked.push(day.day);

        const r = await db.request()
          .input('operation', 'COUNT_FUTURE_APPTS_FOR_SLOT')
          .input('slot_id', slot_id)
          .execute('sp_doctor_schedule');

        const count = r.recordset?.[0]?.cnt ?? 0;
        if (count > 0) {
          conflicts.push({ day: day.day, slot_id, future_appointments: count });
        }
      }

      // (b) Kept-but-retimed slots with TODAY's live bookings -> hard block
      //     (today's patient would silently shift to a new time).
      if (!disablingDay) {
        for (const s of (day.slots || [])) {
          if (s.slot_id == null) continue;
          const prev = curTiming[s.slot_id];
          if (!prev) continue;
          const changed = norm(s.start_time) !== prev.start ||
            norm(s.end_time) !== prev.end;
          if (changed && (await todayCount(s.slot_id)) > 0) {
            todayBlocked.push(day.day);
          }
        }
      }
    }
    if (todayBlocked.length > 0) {
      const days = [...new Set(todayBlocked)];
      return res.status(409).json({
        success: false,
        today_blocked: true,
        days,
        message:
          `You have bookings today (${days.join(', ')}). Today's schedule ` +
          `can't be changed here. Use "Leave" to block the whole day, or ` +
          `reschedule those patients individually from the queue.`,
      });
    }

    if (conflicts.length > 0 && !force) {
      return res.status(409).json({
        success: false,
        message: 'Some slots have future appointments. Confirm before deleting.',
        conflicts
      });
    }

    // ── PASS 2: actually apply the changes
    // Per-patient context for personalized notifications — patient needs to
    // know WHICH appointment was cancelled so they can rebook the right one.
    const affectedAppts = []; // [{patient_id, token, doctor_name, date, time, appointment_id}]

    for (const day of schedule) {
      // UPSERT DAY
      const dayResult = await db.request()
        .input('operation', 'UPSERT_DAY')
        .input('doctor_id', doctor_id)
        .input('day_of_week', day.day)
        .input('is_enabled', day.is_enabled)
        .execute('sp_doctor_schedule');

      const availability_id = dayResult.recordset?.[0]?.availability_id;
      if (!availability_id) {
        throw new Error(`UPSERT_DAY did not return availability_id for ${day.day}`);
      }

      // Re-read existing slot ids for diff
      const existing = await db.request()
        .input('operation', 'GET_DAY_SLOT_IDS')
        .input('doctor_id', doctor_id)
        .input('day_of_week', day.day)
        .execute('sp_doctor_schedule');
      const existingIds = (existing.recordset || []).map(r => r.slot_id);

      const incomingIds = (day.slots || [])
        .map(s => s.slot_id)
        .filter(id => id != null);

      // DELETE removed slots (safe: pass2 only runs after conflict pass)
      // If day is disabled, drop everything for it.
      const disablingDay = day.is_enabled !== 1;
      const removedSlotIds = disablingDay
        ? existingIds
        : existingIds.filter(id => !incomingIds.includes(id));

      // 'reschedule' keeps the appointment alive (status='reschedule') so the
      // patient still sees it and can rebook; 'cancel' marks it 'cancelled'.
      const releaseOp = action === 'reschedule'
        ? 'RESCHEDULE_FUTURE_APPTS_FOR_SLOT'
        : 'CANCEL_FUTURE_APPTS_FOR_SLOT';

      for (const slot_id of removedSlotIds) {
        // Pre-fetch context before the SP changes statuses, so we can build
        // personalized "Dr. X on 15 Jun at 10:30 AM" notifications.
        const details = await db.request()
          .input('operation', 'APPT_CONTEXT_SLOT')
          .input('slot_id', slot_id)
          .execute('sp_notification');

        for (const row of (details.recordset || [])) {
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

        // Release future appointments on this slot
        await db.request()
          .input('operation', releaseOp)
          .input('slot_id', slot_id)
          .execute('sp_doctor_schedule');

        // For 'cancel' mode, normalize status to 'CancleD' so the patient app
        // shows "Cancelled by Doctor" (the release SP otherwise sets generic
        // 'cancelled' which looks identical to a patient self-cancel).
        // Reschedule mode leaves status='reschedule' — that's its own state.
        if (action === 'cancel') {
          const slotApptIds = (details.recordset || []).map(r => r.appointment_id);
          await Promise.all(slotApptIds.map(aid =>
            db.request()
              .input('operation', 'MARK_APPT_DOCTOR_CANCELLED')
              .input('appointment_id', aid)
              .execute('sp_appointment')
              .catch(err =>
                log.error('status normalize err: ' + aid + ' ' + err.message),
              ),
          ));
        }

        // Now safe to delete the slot row
        await db.request()
          .input('operation', 'DELETE_SLOT')
          .input('slot_id', slot_id)
          .execute('sp_doctor_schedule');
      }

      // UPSERT each slot, only if day enabled
      if (day.is_enabled === 1 && Array.isArray(day.slots)) {
        for (const slot of day.slots) {
          await db.request()
            .input('operation', 'UPSERT_SLOT')
            .input('availability_id', availability_id)
            .input('slot_id', slot.slot_id ?? null)
            .input('start_time', slot.start_time)
            .input('end_time', slot.end_time)
            .input('booking_mode', slot.booking_mode)
            .input('slot_duration', slot.slot_duration ?? null)
            .input('max_queue_length', slot.max_queue_length ?? null)
            .execute('sp_doctor_schedule');
        }
      }
    }

    if (affectedAppts.length > 0) {
      const isReschedule = action === 'reschedule';
      const title = isReschedule ? 'Please Reschedule' : 'Appointment Cancelled';

      const tasks = affectedAppts.map((a) => {
        const when = a.date && a.time ? `${a.date} at ${a.time}`
          : a.date ? a.date
            : a.time ? `at ${a.time}`
              : '';
        const body = isReschedule
          ? `Dr. ${a.doctor_name}'s schedule changed. Your appointment${when ? ' on ' + when : ''} needs to be rebooked. Tap to book again.`
          : `Your appointment with Dr. ${a.doctor_name}${when ? ' on ' + when : ''} has been cancelled. Tap to book again.`;
        return { ...a, title, body };
      });

      // Inbox rows first so a device that refetches on push arrival sees them.
      await Promise.all(tasks.map(t =>
        insertNotification(t.patient_id, t.title, t.body, 'appointment', t.appointment_id),
      ));

      // Per-patient FCM (parallel). Generic multicast can't carry per-patient
      // bodies, so we fan out one send per token.
      await Promise.all(tasks
        .filter(t => t.token && t.token.trim() !== '')
        .map(t =>
          admin.messaging().send({
            token: t.token,
            notification: { title: t.title, body: t.body },
            data: {
              type: 'appointment',
              action: isReschedule ? 'rebook' : 'cancelled',
              doctor_id: String(doctor_id),
              appointment_id: String(t.appointment_id),
            },
          }).catch(err => log.error('FCM err (saveDoctorSchedule): ' + err.message)),
        ),
      );
    }

    return res.status(200).json({
      success: true,
      message: 'Schedule saved successfully',
      cancelled_notifications: affectedAppts.length,
      error: null
    });

  } catch (error) {
    log.error('saveDoctorSchedule error: ' + error.message);
    return res.status(500).json({
      success: false,
      message: 'Error saving schedule',
      error: error.message
    });
  }
});

// ──────────────────────────────────────────────────────────────────────────
//  DOCTOR LEAVE / SUTTI  (date-range unavailability — industry "Mark
//  Unavailable" pattern). Cancels every future booked/in_progress
//  appointment in the range and FCM-notifies the affected patients.
// ──────────────────────────────────────────────────────────────────────────
router.post('/addDoctorLeave', async (req, res) => {
  const { doctor_id, from_date, to_date, reason, force } = req.body;

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

router.get('/doctorLeaves/:doctor_id', async (req, res) => {
  const { doctor_id } = req.params;
  try {
    const result = await db.request()
      .input('operation', 'LIST_LEAVE')
      .input('doctor_id', doctor_id)
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
  const { doctor_id, leave_id } = req.body;

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


router.post('/insertPrescription', async (req, res) => {
  const {
    patient_id,
    doctor_id,
    prescription_date,
    symptoms,
    diagnosis,
    user_type,
    appointment_id,
    clinical_notes,
    follow_up_date,
    advice,
    medicines = [],
  } = req.body;

  if (!patient_id) {
    return res.status(400).json({ success: false, message: 'patient_id is required' });
  }

  if (!doctor_id) {
    return res.status(400).json({ success: false, message: 'doctor_id is required' });
  }

  if (!Array.isArray(medicines)) {
    return res.status(400).json({ success: false, message: 'medicines must be an array' });
  }

  const clean = (v) => (v === '' || v === undefined ? null : v);

  try {
    let prescription_id = null;
    let patientToken = null;
    let doctorName = null;

    const rows = medicines.length > 0 ? medicines : [null];

    for (let i = 0; i < rows.length; i++) {
      const med = rows[i];

      const request = db.request();

      request.input('operation', 'Insert');
      request.input('prescription_id', prescription_id ?? 0);
      request.input('patient_id', patient_id);
      request.input('doctor_id', doctor_id);
      request.input('prescription_date', clean(prescription_date) ?? new Date());
      request.input('symptoms', clean(symptoms));
      request.input('diagnosis', clean(diagnosis));
      request.input('clinical_notes', clean(clinical_notes));
      request.input('follow_up_date', clean(follow_up_date));
      request.input('advice', clean(advice));
      request.input('created_at', new Date());
      request.input('user_type', user_type);
      request.input('appointment_id', appointment_id);

      request.input('medicine_id', med?.medicine_id ?? null);
      request.input('medicine_type_id', med?.medicine_type_id ?? null);
      request.input('frequency', clean(med?.frequency));
      request.input('duration', clean(med?.duration));
      request.input('timing', clean(med?.timing));
      request.input('tablet_dosage', clean(med?.tablet_dosage));
      request.input('syrup_dosage_ml', clean(med?.syrup_dosage_ml));
      request.input('inj_dosage', clean(med?.inj_dosage));
      request.input('inj_route', clean(med?.inj_route));
      request.input('drops_count', clean(med?.drops_count));
      request.input('drops_application', clean(med?.drops_application));
      request.input('lotion_apply_area', clean(med?.lotion_apply_area));
      request.input('spray_puffs', clean(med?.spray_puffs));
      request.input('spray_usage', clean(med?.spray_usage));
      request.input('lotion_usage', clean(med?.lotion_usage));

      // ── Powders ───────────────────────────────────────────────
      request.input('powder_dosage', clean(med?.powder_dosage));
      request.input('powder_form', clean(med?.powder_form));

      // ── Inhalers ──────────────────────────────────────────────
      request.input('inhaler_puffs', clean(med?.inhaler_puffs));
      request.input('inhaler_type', clean(med?.inhaler_type));
      request.input('inhaler_technique', clean(med?.inhaler_technique));
      request.input('inhaler_usage', clean(med?.inhaler_usage));

      const result = await request.execute('sp_prescription');

      const row = result.recordset?.[0];

      if (!row || row.success === 0) {
        return res.status(500).json({
          success: false,
          message: row?.message || 'Prescription failed'
        });
      }

      // ✅ FIRST CALL → GET ID + TOKEN
      if (i === 0) {
        prescription_id = row.prescription_id;
        // SP may return the FCM token under either alias; accept both.
        patientToken = row.token || row.fcm_token;
        // Doctor name is optional — used to personalise the "Appointment
        // Complete — review it" body. Falls back below if the SP doesn't
        // return it.
        doctorName = row.doctor_name || row.doctorName || null;
        log.debug('[insertPrescription] SP row keys: ' + Object.keys(row).join(', '));
        log.debug('[insertPrescription] patientToken: ' + (patientToken ? '[REDACTED]' : 'null'));

        if (!prescription_id) {
          return res.status(500).json({
            success: false,
            message: 'Failed to create prescription'
          });
        }
      }
    }

    // sp_prescription doesn't always echo the patient's FCM token. Fallback is a
    // direct read from patients.token (same column populated by sp_doctor_login's
    // 'saveFirebaseToken' op for role='patient', and used in the reverse lookup
    // at the top of this file).
    if (!patientToken) {
      try {
        const tokenLookup = await db.request()
          .input('patient_id', patient_id)
          .query('SELECT TOP 1 token FROM patients WHERE patient_id = @patient_id');
        patientToken = tokenLookup.recordset?.[0]?.token || null;
        log.debug('[insertPrescription] token fetched via patients fallback: ' + (patientToken ? '[REDACTED]' : 'null'));
      } catch (lookupErr) {
        log.error('[insertPrescription] token lookup failed: ' + lookupErr.message);
      }
    }

    // 🔔 SEND TWO NOTIFICATIONS — completing a consultation triggers both:
    //   1) "Appointment Complete — review it"  → opens the review dialog
    //   2) "Prescription Assigned — tap to view" → opens the prescription
    // The review one fires only when we have an appointment_id to attach
    // to (the dialog needs it). Both share the cached patientToken so we
    // don't double-lookup.
    const drLabel = doctorName ? `Dr. ${doctorName}` : 'the doctor';

    if (appointment_id) {
      const reviewTitle = 'Appointment Complete';
      const reviewBody  =
        `Your appointment with ${drLabel} is complete. Tap to leave a review.`;

      await insertNotification(
        patient_id, reviewTitle, reviewBody, 'rating', appointment_id,
      );

      if (patientToken) {
        try {
          await admin.messaging().send({
            token: patientToken,
            notification: { title: reviewTitle, body: reviewBody },
            // appointment_id lets the frontend look up the row and pop the
            // review dialog with doctor/patient context already populated.
            data: {
              type: 'rating',
              appointment_id: String(appointment_id),
            },
          });
        } catch (err) {
          log.error('[insertPrescription] review FCM FAILED: ' + (err.code || '') + ' ' + err.message);
        }
      }
    } else {
      log.warn('[insertPrescription] appointment_id missing — review notification skipped');
    }

    const presTitle = 'Prescription Assigned';
    const presBody = 'Doctor has assigned prescription to you. Please review it.';

    // Inbox row first — patient_id is already known here, no token lookup needed.
    await insertNotification(patient_id, presTitle, presBody, 'prescription', prescription_id);

    if (patientToken) {
      try {
        const fcmResp = await admin.messaging().send({
          token: patientToken,
          notification: { title: presTitle, body: presBody },
          data: {
            type: 'prescription',
            prescription_id: String(prescription_id),
          },
        });
        log.info('[insertPrescription] FCM send OK: ' + fcmResp);
      } catch (err) {
        log.error('[insertPrescription] FCM send FAILED: ' + (err.code || '') + ' ' + err.message);
      }
    } else {
      log.warn('[insertPrescription] no patientToken — push skipped (inbox row saved)');
    }

    return res.status(200).json({
      success: true,
      prescription_id,
      message: 'Prescription created successfully'
    });

  } catch (err) {
    log.error('Error in /insertPrescription: ' + err.message);
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

router.post('/appointment/queueNext', async (req, res) => {
  const { doctor_id, appointment_id } = req.body;

  if (!doctor_id) {
    return res.status(400).json({ success: false, message: 'doctor_id is required' });
  }
  if (!appointment_id) {
    return res.status(400).json({ success: false, message: 'appointment_id is required' });
  }

  try {
    const result = await db.request()
      .input('operation', 'NEXT_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .execute('sp_appointment');

    const row = result.recordset?.[0] ?? {};

    if (row.success !== 1) {
      return res.json({
        success: false,
        message: row.message || 'Queue next failed'
      });
    }

    const token = row.token;

    log.debug('queueNext: next patient token present: ' + !!token);

    // 🔔 SEND NOTIFICATION TO NEXT PATIENT
    if (token) {
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

    sendProximityNotifications(doctor_id);
    const nextServing = await fetchCurrentServing(appointment_id);
    emitQueueUpdate(req, 'next', doctor_id, { current_serving: nextServing });

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
    const result = await db.request()
      .input('operation', 'QUEUE_START')
      .input('queue_id', queue_id)
      .input('doctor_id', doctor_id)
      .execute('sp_appointment');

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

    if (tokens.length === 0) {
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
        .execute('sp_notification');
      doctorName = ctx.recordset?.[0]?.doctor_name || 'your doctor';
    } catch (e) { log.error('[queueStart] name lookup failed: ' + e.message); }
    const startTitle = 'Doctor Arrived';
     const startBody = `Dr. ${doctorName} has started the queue. Please be ready.`;

    for (const tk of tokens) {
      await insertNotificationForToken(tk, startTitle, startBody, 'queue', doctor_id);
    }
    

    // 🔥 SEND NOTIFICATION
    const message = {
      notification: { title: startTitle, body: startBody },
      data: { type: 'queue' },
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    sendProximityNotifications(doctor_id);
    emitQueueUpdate(req, 'queue_started', doctor_id, { queue_id });

    return res.json({
      success: true,
      message: 'Queue started and notifications sent',
      total_tokens: tokens.length,
      success_count: response.successCount,
      failure_count: response.failureCount
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
    const result = await db.request()
      .input('operation', 'QUEUE_PAUSE')
      .input('queue_id', queue_id)
      .input('doctor_id', doctor_id)
      .execute('sp_appointment');

    // SP returns 2 separate result sets: [0] = status, [1] = token rows.
    // node-mssql's `result.recordset` is only the FIRST recordset, so tokens
    // live in `result.recordsets[1]`.
    const recordsets = result.recordsets || [];
    const statusRow  = recordsets[0]?.[0] || {};
    const tokenRows  = recordsets[1] || [];

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
    if (tokens.length > 0) {
		 let doctorName = 'your doctor';
      try {
        const ctx = await db.request()
          .input('operation', 'APPT_CONTEXT_QUEUE')
          .input('doctor_id', doctor_id)
          .input('queue_id', queue_id)
          .execute('sp_notification');
        doctorName = ctx.recordset?.[0]?.doctor_name || 'your doctor';
      } catch (e) { log.error('[queuePause] name lookup failed: ' + e.message); }
      const pauseTitle = 'Queue Paused';
       const pauseBody = `Dr. ${doctorName} has paused the queue. Please wait.`;

      for (const tk of tokens) {
        await insertNotificationForToken(tk, pauseTitle, pauseBody, 'queue', doctor_id);
      }

      const message = {
        notification: { title: pauseTitle, body: pauseBody },
        data: { type: 'queue' },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);

      emitQueueUpdate(req, 'queue_paused', doctor_id, { queue_id });
      return res.json({
        success: true,
        message: 'Queue paused and notifications sent',
        total_tokens: tokens.length,
        success_count: response.successCount,
        failure_count: response.failureCount
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
    // Pre-fetch personalized context BEFORE the SP cancels everything.
    const detailsRes = await db.request()
      .input('operation', 'APPT_CONTEXT_QUEUE')
      .input('doctor_id', doctor_id)
      .input('queue_id', queue_id)
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
      .execute('sp_appointment');

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
    const result = await db.request()
      .input('operation', 'SKIP_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .input('is_next', is_next)
      .execute('sp_appointment');

    const row = result.recordset?.[0] ?? {};

    // ✅ CHECK SUCCESS
    if (row.success !== 1) {
      return res.json({
        success: false,
        message: row.message || 'Queue skip failed'
      });
    }

    const token = row.token;

    log.debug('queueSkip: skipped patient token present: ' + !!token);

    // 🔔 SEND ONLY TO SKIPPED PATIENT
    if (token) {
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

    sendProximityNotifications(doctor_id);
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
      .execute('sp_appointment');

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
    const result = await db.request()
      .input('operation', 'START_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .execute('sp_appointment');

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
  const { doctor_id, appointment_id } = req.body;

  if (!doctor_id || !appointment_id) {
    return res.status(400).json({
      success: false,
      message: 'doctor_id and appointment_id are required'
    });
  }

  try {
    const result = await db.request()
      .input('operation', 'END_SESSION')
      .input('doctor_id', doctor_id)
      .input('appointment_id', appointment_id)
      .execute('sp_appointment');

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
    sendProximityNotifications(doctor_id);
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
      .execute('sp_appointment');

    // SP returns 2 separate result sets: [0] = status, [1] = token rows.
    // node-mssql's `result.recordset` is only the FIRST recordset, so tokens
    // live in `result.recordsets[1]`.
    const recordsets = result.recordsets || [];
    const statusRow  = recordsets[0]?.[0] || {};
    const tokenRows  = recordsets[1] || [];

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

      for (const tk of tokens) {
        await insertNotificationForToken(tk, pauseTitle, pauseBody, 'queue', queue_id);
      }

      const message = {
        notification: { title: pauseTitle, body: pauseBody },
        data: { type: 'queue' },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      log.info('[queuePauseEmergency] FCM result: ' + response.successCount + '/' + tokens.length);

      emitQueueUpdate(req, 'queue_paused_emergency', emergencyDoctorId, { queue_id });
      return res.json({
        success: true,
        message: statusRow.message || 'Queue paused successfully',
        total_tokens: tokens.length,
        success_count: response.successCount,
        failure_count: response.failureCount
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


//cron job ---------------------------------------------------------------------------------------------------------------------------------
cron.schedule('0 14 * * *', async () => {
  try {
    const result = await db.request()
      .input('operation', 'TOMORROW_PATIENT_APPOINTMENTS')
      .execute('sp_appointment');

    const rows = result.recordset || [];

    if (rows.length === 0) {
      log.info('[cron 14:00] No appointments for tomorrow');
      return;
    }

    let successCount = 0;
    let failureCount = 0;

    for (const row of rows) {
      const token = row.patient_token;
      const doctorName = row.doctor_name;
      if (!token) continue;

      // Date from the DATE column, time from the TIME column. Formatting the
      // date's own time always yields midnight → 05:30 am in IST; start_time
      // holds the real booked slot time.
      const formattedDate = formatApptDate(row.appointment_date);
      const formattedTime = formatApptTime(row.start_time);
      const remTitle = 'Appointment Reminder';
      const remBody = `Your appointment with Dr. ${doctorName} is scheduled on ${formattedDate} at ${formattedTime}.`;

      await insertNotificationForToken(token, remTitle, remBody, 'appointment', row.appointment_id);

      const message = {
        token: token,
        notification: { title: remTitle, body: remBody },
        // appointment_id lets the killed-app FCM tap auto-open the detail
        // sheet for the reminded appointment.
        data: { type: 'appointment', appointment_id: String(row.appointment_id) },
      };

      try {
        await admin.messaging().send(message);
        successCount++;
      } catch (err) {
        log.error('FCM Error: ' + err.message);
        failureCount++;
      }
    }

    log.info(`[cron 14:00] Tomorrow reminders sent: ${successCount} ok, ${failureCount} failed / ${rows.length} total`);

  } catch (error) {
    log.error('[cron 14:00] Failed to send reminders: ' + error.message);
  }
}, { timezone: 'Asia/Kolkata' });


cron.schedule('0 15 * * *', async () => {
  try {
    const result = await db.request()
      .input('operation', 'TOMORROW_PATIENT_APPOINTMENTS')
      .execute('sp_appointment');

    const rows = result.recordset || [];

    if (rows.length === 0) {
      log.info('[cron 15:00] No appointments for tomorrow');
      return;
    }

    for (const row of rows) {
      const token = row.patient_token;
      const doctorName = row.doctor_name;
      if (!token) continue;

      // Date from the DATE column, time from the TIME column (see 14:00 cron).
      const formattedDate = formatApptDate(row.appointment_date);
      const formattedTime = formatApptTime(row.start_time);

      const remTitle = 'Appointment Reminder';
      const remBody = `Your appointment with Dr. ${doctorName} is scheduled on ${formattedDate} at ${formattedTime}.`;

      await insertNotificationForToken(token, remTitle, remBody, 'appointment', row.appointment_id);

      const message = {
        token: token,
        notification: { title: remTitle, body: remBody },
        // appointment_id lets the killed-app FCM tap auto-open the detail
        // sheet for the reminded appointment.
        data: { type: 'appointment', appointment_id: String(row.appointment_id) },
      };

      try {
        await admin.messaging().send(message);
      } catch (err) {
        log.error('FCM Error: ' + err.message);
      }
    }

    log.info(`[cron 15:00] Tomorrow reminders sent: ${rows.length} total`);

  } catch (error) {
    log.error('[cron 15:00] Failed to send reminders: ' + error.message);
  }
}, { timezone: 'Asia/Kolkata' });


cron.schedule('0 16 * * *', async () => {
  try {
    const result = await db.request()
      .input('operation', 'YESTERDAY_COMPLETED_PATIENTS')
      .execute('sp_appointment');

    const rows = result.recordset || [];

    if (rows.length === 0) {
      log.info('[cron 16:00] No patients to send rating request');
      return;
    }

    let successCount = 0;
    let failureCount = 0;

    for (const row of rows) {
      const token = row.patient_token;
      const doctorName = row.doctor_name;
      const appointmentId = row.appointment_id;

      if (!token) continue;

      const rateTitle = 'Rate Your Experience';
      const rateBody = `How was your consultation with Dr. ${doctorName}? Tap to rate.`;

      await insertNotificationForToken(token, rateTitle, rateBody, 'rating', appointmentId);

      const message = {
        token: token,
        notification: { title: rateTitle, body: rateBody },
        data: {
          appointment_id: appointmentId.toString(),
          type: 'rating',
        },
      };

      try {
        await admin.messaging().send(message);
        successCount++;
      } catch (err) {
        log.error('FCM Error: ' + err.message);
        failureCount++;
      }
    }

    log.info(`[cron 16:00] Rating notifications sent: ${successCount} ok, ${failureCount} failed / ${rows.length} total`);

  } catch (error) {
    log.error('[cron 16:00] Failed to send rating notifications: ' + error.message);
  }

}, { timezone: 'Asia/Kolkata' });


// Follow-up reminders (Practo pattern). When a doctor sets a follow_up_date on a
// prescription, the patient is reminded the day BEFORE and again the DAY OF so
// they book the review visit. sp_prescription 'FollowUpReminders' returns one row
// per prescription whose follow_up_date is today or tomorrow, each carrying the
// patient's FCM token (patient or family-head), the doctor name and a
// reminder_kind flag ('day_before' | 'day_of').
//
// Extracted from the cron so the /test/followup-reminders debug route can fire it
// on demand without waiting for 09:00. `tag` only labels the log line.
async function runFollowUpReminders(tag = 'cron 09:00') {
  const result = await db.request()
    .input('operation', 'FollowUpReminders')
    .execute('sp_prescription');

  const rows = result.recordset || [];

  if (rows.length === 0) {
    log.info(`[${tag}] No follow-up reminders due`);
    return { total: 0, sent: 0, failed: 0, skipped: 0 };
  }

  let successCount = 0;
  let failureCount = 0;
  let skippedCount = 0;

  for (const row of rows) {
    const token = row.patient_token;
    const doctorName = row.doctor_name || 'your doctor';
    const kind = row.reminder_kind; // 'day_before' | 'day_of'

    if (!token || !kind) { skippedCount++; continue; }

    const title = kind === 'day_of' ? 'Follow-up Today' : 'Follow-up Tomorrow';
    const body = kind === 'day_of'
      ? `Your follow-up with Dr. ${doctorName} is today. Tap to book your visit.`
      : `Your follow-up with Dr. ${doctorName} is tomorrow. Tap to book your visit.`;

    // type 'appointment' with no appointment_id → the tap lands on the
    // appointments tab where the patient can book the follow-up. doctor_id is
    // carried for any future "pre-select this doctor" booking deep link.
    await insertNotificationForToken(token, title, body, 'appointment', null);

    const message = {
      token,
      notification: { title, body },
      data: {
        type: 'appointment',
        action: 'followup',
        doctor_id: String(row.doctor_id ?? ''),
        prescription_id: String(row.prescription_id ?? ''),
      },
    };

    try {
      await admin.messaging().send(message);
      successCount++;
    } catch (err) {
      log.error('FCM Error: ' + err.message);
      failureCount++;
    }
  }

  log.info(`[${tag}] Follow-up reminders sent: ${successCount} ok, ${failureCount} failed, ${skippedCount} skipped / ${rows.length} total`);
  return { total: rows.length, sent: successCount, failed: failureCount, skipped: skippedCount };
}

cron.schedule('0 9 * * *', async () => {
  try {
    await runFollowUpReminders('cron 09:00');
  } catch (error) {
    log.error('[cron 09:00] Failed to send follow-up reminders: ' + error.message);
  }
}, { timezone: 'Asia/Kolkata' });


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
      .execute('sp_appointment');

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
  const { name, mobile_no, doctor_id, appointment_date, start_time, slot_id, user_type, symptoms, gender_id, family_id, patient_id: existingPatientId } = req.body;

  if (!name || !mobile_no || !doctor_id || !appointment_date) {
    return res.status(400).json({ success: false, message: 'name, mobile_no, doctor_id, appointment_date required' });
  }

  try {
    let patient_id;

    if (family_id) {
      // Family member booking: insert into family_members, then book appointment under the
      // primary patient's id (family_id) with user_type=2.
      const famRes = await db.request()
        .input('operation', 'Insert')
        .input('member_id', null)
        .input('family_id', parseInt(family_id))
        .input('name', String(name).trim())
        .input('Gender_id', gender_id ? parseInt(gender_id) : null)
        .input('relation_id', null)
        .input('DOB', null)
        .input('mobile_no', mobile_no)
        .execute('sp_family_members');
      patient_id = famRes.recordset[0]?.member_id;
      log.info(`walkInBook family: family_id=${family_id} member_id=${patient_id} recordset=${JSON.stringify(famRes.recordset)}`);
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
        .execute('sp_patients');
      patient_id = insertRes.recordset[0]?.patient_id;
      if (!patient_id) throw new Error('Failed to create patient profile');
    }

    // Step 2: Check doctor leave
    const blockRes = await db.request()
      .input('operation', 'IS_BLOCKED')
      .input('doctor_id', doctor_id)
      .input('from_date', appointment_date)
      .execute('sp_doctor_leave');

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
      .execute('sp_appointment');

    const booked = bookRes.recordset[0].success === 1;
    log.info(`walkInBook: patient_id=${patient_id} user_type=${user_type} family_id=${family_id||null} booked=${booked} msg=${bookRes.recordset[0].message}`);
    if (booked) emitQueueUpdate(req, 'booked', doctor_id);

    return res.json({
      success: booked,
      message: bookRes.recordset[0].message,
      patient_id,
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
    .execute('sp_notification');

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
    .execute('sp_appointment');
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
        .execute('sp_appointment');
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
  let slotsCancelled = 0;
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
setTimeout(() => { closeStaleSessions(); }, 5000);

module.exports = router;
module.exports.closeStaleSessions = closeStaleSessions; 