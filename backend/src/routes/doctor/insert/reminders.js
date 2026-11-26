// /doctor/insert — Scheduled push reminders (cron): day-before, follow-ups.

const db = require('../../../db');
const admin = require('../../../fcm');
const cron = require('node-cron');
const log = require('../../../middleware/logger');

const {
  insertNotificationForToken,
  formatApptDate,
  formatApptTime,
} = require('./shared');
const prescriptionsSql = require('../../../queries/prescriptions');
const appointmentsSql = require('../../../queries/appointments');

//cron job ---------------------------------------------------------------------------------------------------------------------------------
cron.schedule('0 14 * * *', async () => {
  try {
    const result = await db.request()
      .input('operation', 'TOMORROW_PATIENT_APPOINTMENTS')
      .run(appointmentsSql);

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
      .run(appointmentsSql);

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
      .run(appointmentsSql);

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
    .run(prescriptionsSql);

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
    const at = row.follow_up_time ? ` at ${row.follow_up_time}` : '';

    if (!token || !kind) { skippedCount++; continue; }

    const title = kind === 'day_of' ? 'Follow-up Today' : 'Follow-up Tomorrow';
    const body = kind === 'day_of'
      ? `Your follow-up with Dr. ${doctorName} is today${at}. Tap to book your visit.`
      : `Your follow-up with Dr. ${doctorName} is tomorrow${at}. Tap to book your visit.`;

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
