var express = require('express');
var router = express.Router();
var db = require('../db'); // go from admin/ to routes/
const sql = require("mssql");
const multer = require("multer");
const path = require("path");
const fs = require("fs-extra");
const admin = require("firebase-admin");
const cron = require('node-cron');

const serviceAccount = require("../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

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
    console.error('insertNotification failed:', err.message);
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
    console.error('insertNotificationForToken failed:', err.message);
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
  let s = String(t);
  if (s.includes('T')) s = s.split('T')[1].split('.')[0];
  const parts = s.split(':');
  let h = parseInt(parts[0], 10);
  const m = String(parts[1] || '00').padStart(2, '0');
  if (isNaN(h)) return '';
  const ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12 || 12;
  return `${h}:${m} ${ampm}`;
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
  console.log('saveDoctorSchedule payload:', JSON.stringify({
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
          end:   String(r.end_time   || '').slice(0, 5),
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
                          norm(s.end_time)   !== prev.end;
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
            patient_id:     row.owner_id,
            token:          row.owner_token,
            doctor_name:    row.doctor_name || 'your doctor',
            date:           formatApptDate(row.appointment_date),
            time:           formatApptTime(row.start_time),
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
                console.error('status normalize err:', aid, err.message),
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
                    : a.date         ? a.date
                    : a.time         ? `at ${a.time}`
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
              type:           'appointment',
              action:         isReschedule ? 'rebook' : 'cancelled',
              doctor_id:      String(doctor_id),
              appointment_id: String(t.appointment_id),
            },
          }).catch(err => console.error('FCM err (saveDoctorSchedule):', err.message)),
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
    console.error('saveDoctorSchedule error:', error);
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
        patient_id:     row.owner_id,
        token:          row.owner_token,
        doctor_name:    row.doctor_name || 'your doctor',
        date:           formatApptDate(row.appointment_date),
        time:           formatApptTime(row.start_time),
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
            console.error('status normalize err:', a.appointment_id, err.message),
          ),
      ));
    }

    if (affectedAppts.length > 0) {
      const title = 'Appointment Cancelled';
      const tasks = affectedAppts.map((a) => {
        const when = a.date && a.time ? `${a.date} at ${a.time}`
                    : a.date         ? a.date
                    : a.time         ? `at ${a.time}`
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
              type:           'appointment',
              action:         'cancelled',
              doctor_id:      String(doctor_id),
              appointment_id: String(t.appointment_id),
            },
          }).catch(err => console.error('FCM err (addDoctorLeave):', err.message)),
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
    console.error('addDoctorLeave error:', error);
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
    console.error('cancelDoctorLeave error:', error);
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

      request.input('medicine_id',       med?.medicine_id ?? null);
      request.input('medicine_type_id',  med?.medicine_type_id ?? null);
      request.input('frequency',         clean(med?.frequency));
      request.input('duration',          clean(med?.duration));
      request.input('timing',            clean(med?.timing));
      request.input('tablet_dosage',     clean(med?.tablet_dosage));
      request.input('syrup_dosage_ml',   clean(med?.syrup_dosage_ml));
      request.input('inj_dosage',        clean(med?.inj_dosage));
      request.input('inj_route',         clean(med?.inj_route));
      request.input('drops_count',       clean(med?.drops_count));
      request.input('drops_application', clean(med?.drops_application));
      request.input('lotion_apply_area', clean(med?.lotion_apply_area));
      request.input('spray_puffs',       clean(med?.spray_puffs));
      request.input('spray_usage',       clean(med?.spray_usage));
      request.input('lotion_usage',      clean(med?.lotion_usage));
		
      // ── Powders ───────────────────────────────────────────────
      request.input('powder_dosage',      clean(med?.powder_dosage));
      request.input('powder_form',        clean(med?.powder_form));

      // ── Inhalers ──────────────────────────────────────────────
      request.input('inhaler_puffs',      clean(med?.inhaler_puffs));
      request.input('inhaler_type',       clean(med?.inhaler_type));
      request.input('inhaler_technique',  clean(med?.inhaler_technique));
      request.input('inhaler_usage',      clean(med?.inhaler_usage));

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
        console.log('[insertPrescription] SP row keys:', Object.keys(row));
        console.log('[insertPrescription] patientToken:', patientToken);

        if (!prescription_id) {
          return res.status(500).json({
            success: false,
            message: 'Failed to create prescription'
          });
        }
      }
    }

    // 🔔 If SP didn't return a token, look it up via SP so the patient still gets notified.
    if (!patientToken) {
      try {
        const tokenLookup = await db.request()
          .input('operation', 'getFirebaseToken')
          .input('patient_id', patient_id)
          .execute('sp_doctor_login');
        const lookupRow = tokenLookup.recordset?.[0];
        patientToken = lookupRow?.fcm_token || lookupRow?.token || null;
        console.log('[insertPrescription] token fetched via SP fallback:', patientToken);
      } catch (lookupErr) {
        console.error('[insertPrescription] token lookup failed:', lookupErr.message);
      }
    }

    // 🔔 SEND NOTIFICATION (ONLY ONCE)
    const presTitle = 'Prescription Assigned';
    const presBody  = 'Doctor has assigned prescription to you. Please review it.';

    // Inbox row first — patient_id is already known here, no token lookup needed.
    await insertNotification(patient_id, presTitle, presBody, 'prescription', prescription_id);

    if (patientToken) {
      try {
        const fcmResp = await admin.messaging().send({
          token: patientToken,
          notification: { title: presTitle, body: presBody },
          data: { type: 'prescription' },
        });
        console.log('[insertPrescription] FCM send OK:', fcmResp);
      } catch (err) {
        console.error('[insertPrescription] FCM send FAILED:', err.code, err.message);
      }
    } else {
      console.warn('[insertPrescription] no patientToken — push skipped (inbox row saved)');
    }

    return res.status(200).json({
      success: true,
      prescription_id,
      message: 'Prescription created successfully'
    });

  } catch (err) {
    console.error('Error in /insertPrescription:', err);
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

    console.log("NEXT PATIENT TOKEN:", token);

    // 🔔 SEND NOTIFICATION TO NEXT PATIENT
    if (token) {
      const nextTitle = 'Your Turn Now';
      const nextBody  = 'Doctor is ready to see you. Please proceed.';

      await insertNotificationForToken(token, nextTitle, nextBody, 'appointment', appointment_id);

      await admin.messaging().send({
        token: token,
        notification: { title: nextTitle, body: nextBody },
        data: { type: 'appointment' },
      });
    }

    return res.json({
      success: true,
      message: row.message ?? 'Queue next done'
    });

  } catch (error) {
    console.error(error);
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

    const rows = result.recordset || [];

    // 🔥 FIRST ROW = STATUS
    const statusRow = rows[0] || {};

 /* if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow|| 'Queue start failed'
      });
    }*/

    // 🔥 REMAINING ROWS = TOKENS
    const tokens = rows
      .slice(1) // skip first row
      .map(r => r.token)
      .filter(t => t && t.trim() !== '');

    if (tokens.length === 0) {
      return res.json({
        success: true,
        message: 'Queue started, no patients to notify'
      });
    }

    const startTitle = 'Doctor Arrived';
    const startBody  = 'Doctor has started serving. Please be ready.';

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
  const { doctor_id , queue_id} = req.body;

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

    const rows = result.recordset || [];

    // 🔥 FIRST ROW = STATUS
    const statusRow = rows[0] || {};

    // ✅ CHECK SUCCESS
    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow.message || 'Queue pause failed'
      });
    }

    // 🔥 REMAINING ROWS = TOKENS
    const tokens = rows
      .slice(1) // skip first row
      .map(r => r.token)
      .filter(t => t && t.trim() !== '');

    console.log("TOKENS:", tokens);

    // 🔔 SEND NOTIFICATION
    if (tokens.length > 0) {
      const pauseTitle = 'Queue Paused';
      const pauseBody  = 'Doctor has paused the queue. Please wait.';

      for (const tk of tokens) {
        await insertNotificationForToken(tk, pauseTitle, pauseBody, 'queue', doctor_id);
      }

      const message = {
        notification: { title: pauseTitle, body: pauseBody },
        data: { type: 'queue' },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);

      return res.json({
        success: true,
        message: 'Queue paused and notifications sent',
        total_tokens: tokens.length,
        success_count: response.successCount,
        failure_count: response.failureCount
      });
    }

    // ✅ NO TOKENS CASE
    return res.json({
      success: true,
      message: 'Queue paused, no patients to notify'
    });

  } catch (error) {
    console.error(error);
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
        patient_id:     row.owner_id,
        token:          row.owner_token,
        doctor_name:    row.doctor_name || 'your doctor',
        date:           formatApptDate(row.appointment_date),
        time:           formatApptTime(row.start_time),
        appointment_id: row.appointment_id,
      });
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
              type:           'appointment',
              action:         'cancelled',
              doctor_id:      String(doctor_id),
              appointment_id: String(t.appointment_id),
            },
          }).catch(err => console.error('FCM err (queueStop):', err.message)),
        ),
      );
    }

    return res.json({
      success: true,
      message: statusRow.message || 'Queue stopped',
      cancelled_notifications: affectedAppts.length
    });

  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: 'Queue stop failed', error: error.message });
  }
});


//QUEUE SKIP
router.post('/appointment/queueSkip', async (req, res) => {
  const { doctor_id, appointment_id,is_next } = req.body;

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

    console.log("SKIPPED PATIENT TOKEN:", token);

    // 🔔 SEND ONLY TO SKIPPED PATIENT
    if (token) {
      const skipTitle = 'You were skipped';
      const skipBody  = 'Doctor skipped your turn due to absence. Please contact clinic.';

      await insertNotificationForToken(token, skipTitle, skipBody, 'appointment', appointment_id);

      await admin.messaging().send({
        token: token,
        notification: { title: skipTitle, body: skipBody },
        data: { type: 'appointment' },
      });
    }

    return res.json({
      success: true,
      message: row.message || 'Patient skipped and notified'
    });

  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: 'Queue skip failed',
      error: error.message
    });
  }
});


//QUEUE RECALL
router.post('/appointment/queueRecall', async (req, res) => {
  const { appointment_id } = req.body;

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

    const rows = result.recordset || [];

    // ✅ STATUS
    const statusRow = rows[0] || {};

    if (statusRow.success !== 1) {
      return res.json({
        success: false,
        message: statusRow.message || 'End session failed'
      });
    }

    // 🔥 ONLY 3rd PATIENT TOKEN
    const token = rows[1]?.token;

    console.log("3rd PATIENT TOKEN:", token);

    if (token) {
      const readyTitle = 'Be Ready';
      const readyBody  = 'Your turn is coming soon. Please stay nearby.';

      await insertNotificationForToken(token, readyTitle, readyBody, 'queue', doctor_id);

      await admin.messaging().send({
        token: token,
        notification: { title: readyTitle, body: readyBody },
        data: { type: 'queue' },
      });

      return res.json({
        success: true,
        message: '3rd patient notified successfully'
      });
    }

    return res.json({
      success: true,
      message: 'Session ended, less than 3 patients in queue'
    });

  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: 'End session failed',
      error: error.message
    });
  }
});


// QUEUE PAUSE (EMERGENCY)
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

    const row = result.recordset?.[0] || {};

    if (row.success !== 1) {
      return res.json({
        success: false,
        message: row.message || 'Queue pause failed'
      });
    }

    return res.json({
      success: true,
      message: row.message || 'Queue paused successfully'
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Queue pause failed',
      error: error.message
    });
  }
});


//cron job ---------------------------------------------------------------------------------------------------------------------------------
cron.schedule('0 14 * * *', async () =>{
 try {
    const result = await db.request()
      .input('operation', 'TOMORROW_PATIENT_APPOINTMENTS')
      .execute('sp_appointment');

    const rows = result.recordset || [];

    if (rows.length === 0) {
      return res.json({
        success: true,
        message: 'No appointments for tomorrow'
      });
    }

    let successCount = 0;
    let failureCount = 0;

    for (const row of rows) {
      const token = row.patient_token;
      const doctorName = row.doctor_name;
      const appointmentDate = new Date(row.appointment_date);

      if (!token) continue;

      // 🕒 FORMAT DATE & TIME
      const formattedDate = appointmentDate.toLocaleDateString('en-IN');
      const formattedTime = appointmentDate.toLocaleTimeString('en-IN', {
        hour: '2-digit',
        minute: '2-digit'
      });

      const remTitle = 'Appointment Reminder';
      const remBody  = `Your appointment with Dr. ${doctorName} is scheduled on ${formattedDate} at ${formattedTime}.`;

      await insertNotificationForToken(token, remTitle, remBody, 'appointment', row.appointment_id);

      const message = {
        token: token,
        notification: { title: remTitle, body: remBody },
        data: { type: 'appointment' },
      };

      try {
        await admin.messaging().send(message);
        successCount++;
      } catch (err) {
        console.error("FCM Error:", err.message);
        failureCount++;
      }
    }

    return res.json({
      success: true,
      message: 'Tomorrow reminders sent',
      total: rows.length,
      success_count: successCount,
      failure_count: failureCount
    });

  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: 'Failed to send reminders',
      error: error.message
    });
  }
});


cron.schedule('0 15 * * *', async () =>{
 try {
    const result = await db.request()
		  .input('operation', 'TOMORROW_PATIENT_APPOINTMENTS')
      .execute('sp_appointment');

    const rows = result.recordset || [];

    if (rows.length === 0) {
      return res.json({
        success: true,
        message: 'No appointments for tomorrow'
      });
    }

    for (const row of rows) {
      const token = row.patient_token;
      const doctorName = row.doctor_name;
      const appointmentDate = new Date(row.appointment_date);

      if (!token) continue;

      // 🕒 FORMAT DATE & TIME
      const formattedDate = appointmentDate.toLocaleDateString('en-IN');
      const formattedTime = appointmentDate.toLocaleTimeString('en-IN', {
        hour: '2-digit',
        minute: '2-digit'
      });

      const remTitle = 'Appointment Reminder';
      const remBody  = `Your appointment with Dr. ${doctorName} is scheduled on ${formattedDate} at ${formattedTime}.`;

      await insertNotificationForToken(token, remTitle, remBody, 'appointment', row.appointment_id);

      const message = {
        token: token,
        notification: { title: remTitle, body: remBody },
        data: { type: 'appointment' },
      };

      try {
        await admin.messaging().send(message);
      } catch (err) {
        console.error("FCM Error:", err.message);
      }
    }

    return res.json({
      success: true,
      message: 'Tomorrow reminders sent',
      total: rows.length
    });

  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: 'Failed to send reminders',
      error: error.message
    });
  }
});


cron.schedule('0 16 * * *', async () =>{
	  try {
    const result = await db.request()
      .input('operation', 'YESTERDAY_COMPLETED_PATIENTS')
      .execute('sp_appointment');

    const rows = result.recordset || [];

    if (rows.length === 0) {
      return res.json({
        success: true,
        message: 'No patients to send rating request'
      });
    }

    let successCount = 0;
    let failureCount = 0;

    for (const row of rows) {
      const token = row.patient_token;
      const doctorName = row.doctor_name;
      const appointmentId = row.appointment_id;

      if (!token) continue;

      const rateTitle = 'Rate Your Experience';
      const rateBody  = `How was your consultation with Dr. ${doctorName}? Tap to rate.`;

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
        console.error("FCM Error:", err.message);
        failureCount++;
      }
    }

    return res.json({
      success: true,
      message: 'Rating notifications sent',
      total: rows.length,
      success_count: successCount,
      failure_count: failureCount
    });

  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: 'Failed to send rating notifications',
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
      .execute('sp_appointment');

    const row = result.recordset?.[0] || {};

    if (row.success !== 1) {
      return res.json({
        success: false,
        message: row.message || 'Cancel failed'
      });
    }

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





module.exports = router; 