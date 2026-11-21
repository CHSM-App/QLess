// /doctor/insert — Queue start time and weekly schedule.

const express = require('express');
const db = require('../../../db');
const admin = require('../../../fcm');
const log = require('../../../middleware/logger');

const {
  insertNotification,
  formatApptDate,
  formatApptTime,
} = require('./shared');
const doctorScheduleSql = require('../../../queries/doctorSchedule');
const notificationsSql = require('../../../queries/notifications');
const doctorsSql = require('../../../queries/doctors');
const appointmentsSql = require('../../../queries/appointments');
const slotTodayCountSql = require('../../../queries/slotTodayCount');

const router = express.Router();

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
    const result = await request.run(doctorsSql);

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
  const { doctor_id, clinic_id, schedule, force } = req.body;
  const action = req.body.action === 'reschedule' ? 'reschedule' : 'cancel';
  const addClinic = (r) => { if (clinic_id) r.input('clinic_id', clinic_id); return r; };

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
    const cur = await addClinic(db.request()
      .input('operation', 'GET')
      .input('doctor_id', doctor_id))
      .run(doctorScheduleSql);
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
        .run(slotTodayCountSql);
      return r.recordset?.[0]?.cnt ?? 0;
    };

    for (const day of schedule) {
      const existing = await addClinic(db.request()
        .input('operation', 'GET_DAY_SLOT_IDS')
        .input('doctor_id', doctor_id)
        .input('day_of_week', day.day))
        .run(doctorScheduleSql);

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
          .run(doctorScheduleSql);

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
      const dayResult = await addClinic(db.request()
        .input('operation', 'UPSERT_DAY')
        .input('doctor_id', doctor_id)
        .input('day_of_week', day.day)
        .input('is_enabled', day.is_enabled))
        .run(doctorScheduleSql);

      const availability_id = dayResult.recordset?.[0]?.availability_id;
      if (!availability_id) {
        throw new Error(`UPSERT_DAY did not return availability_id for ${day.day}`);
      }

      // Re-read existing slot ids for diff
      const existing = await addClinic(db.request()
        .input('operation', 'GET_DAY_SLOT_IDS')
        .input('doctor_id', doctor_id)
        .input('day_of_week', day.day))
        .run(doctorScheduleSql);
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
          .run(notificationsSql);

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
          .run(doctorScheduleSql);

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
              .run(appointmentsSql)
              .catch(err =>
                log.error('status normalize err: ' + aid + ' ' + err.message),
              ),
          ));
        }

        // Now safe to delete the slot row
        await db.request()
          .input('operation', 'DELETE_SLOT')
          .input('slot_id', slot_id)
          .run(doctorScheduleSql);
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
            .run(doctorScheduleSql);
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

module.exports = router;
