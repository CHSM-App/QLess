// Helpers shared by the /doctor/insert route files: socket broadcast, offline
// replay detection, current-serving lookup, inbox + push notifications.
const db = require('../../../db');
const sql = require('mssql');
const admin = require('../../../fcm');
const log = require('../../../middleware/logger');
const notificationsSql = require('../../../queries/notifications');
const appointmentsSql = require('../../../queries/appointments');

// Helper — emits a queue_update event to all sockets in clinic_<doctor_id> room.
// req.app.get('io') is available because app.set('io', io) is called in server.js.
function emitQueueUpdate(req, event, doctor_id, extra = {}) {
  const io = req.app.get('io');
  if (io && doctor_id) io.to('clinic_' + doctor_id).emit('queue_update', { event, doctor_id, ...extra });
}

// Actions the doctor took offline are replayed on reconnect carrying
// offline_queued_at (UTC ISO, set on the device when queued). Live pushes like
// "Your Turn Now" for an action older than this are stale — that patient was
// already seen — so routes skip them; socket updates still go out.
// ponytail: trusts the device clock; use server receive time if clocks drift.
const STALE_REPLAY_MS = 10 * 60 * 1000;
function isStaleReplay(req) {
  const t = Date.parse(req.body?.offline_queued_at);
  return Number.isFinite(t) && Date.now() - t > STALE_REPLAY_MS;
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
          AND  a.status   IN ('in_progress', 'completed', 'cancelled', 'cancled', 'skipped')
          AND  NOT EXISTS (
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
      .run(notificationsSql);
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
    // token_hash (migration 009) is indexed; token itself is NVARCHAR(MAX).
    // Typed as NVARCHAR so the hash is over the same bytes as the column's.
    const r = await db.request()
      .input('token', sql.NVarChar(sql.MAX), token)
      .query(`SELECT TOP 1 patient_id FROM patients
              WHERE token_hash = CONVERT(CHAR(64), HASHBYTES('SHA2_256', @token), 2) AND token = @token`);
    const patient_id = r.recordset?.[0]?.patient_id;
    if (!patient_id) return;
    await insertNotification(patient_id, title, body, type, ref_id);
  } catch (err) {
    log.error('insertNotificationForToken failed: ' + err.message);
  }
}

// One inbox row per distinct token owner, in a single statement (queue start /
// pause used to do one lookup + one insert per token, in sequence).
// OPENJSON values are NVARCHAR, so the hash matches Patients.token_hash.
async function insertNotificationsForTokens(tokens, title, body, type, ref_id = null) {
  if (!tokens.length) return;
  await db.request()
    .input('tokens', sql.NVarChar(sql.MAX), JSON.stringify(tokens))
    .input('title', sql.NVarChar(200), title)
    .input('body', sql.NVarChar(1000), body)
    .input('type', sql.VarChar(40), type)
    .input('ref_id', sql.VarChar(40), ref_id != null ? String(ref_id) : null)
    .query(`
      INSERT INTO notifications (patient_id, title, body, type, ref_id)
      SELECT DISTINCT o.patient_id, @title, @body, @type, @ref_id
      FROM OPENJSON(@tokens) j
      CROSS APPLY (
        SELECT TOP 1 p.patient_id FROM patients p
        WHERE p.token_hash = CONVERT(CHAR(64), HASHBYTES('SHA2_256', j.value), 2) AND p.token = j.value
      ) o;
    `);
}

// Queue start / pause: the change is saved and the doctor already answered,
// so the inbox rows and the one multicast push run in the background. Errors
// are logged, never thrown. Returns the promise (tests await it).
function notifyTokensInBackground(tokens, title, body, ref_id, label) {
  return (async () => {
    try {
      await insertNotificationsForTokens(tokens, title, body, 'queue', ref_id);
    } catch (err) {
      log.error(`[${label}] inbox insert failed: ${err.message}`);
    }
    try {
      const r = await admin.messaging().sendEachForMulticast({
        notification: { title, body },
        data: { type: 'queue' },
        tokens,
      });
      log.info(`[${label}] push: ${r.successCount}/${tokens.length}`);
    } catch (err) {
      log.error(`[${label}] push failed: ${err.message}`);
    }
  })();
}

// Once-per-stage notifications. As the queue moves, the same patient would
// cross the same threshold across multiple endSession events — the "30 min" /
// "10 min" / position notification goes out ONCE per stage per appointment.
// ref_id is namespaced as "<appointment_id>:<stage>". Stores the inbox row
// atomically; returns true only for the caller that stored it (that one sends
// the push). On a DB error returns false: a missed push beats a duplicate.
async function insertNotificationOnce(patient_id, title, body, type, ref_id) {
  if (!patient_id || !title || !body || !type || !ref_id) return false;
  try {
    const r = await db.request()
      .input('operation', 'INSERT_ONCE')
      .input('patient_id', patient_id)
      .input('title', title)
      .input('body', body)
      .input('type', type)
      .input('ref_id', String(ref_id))
      .run(notificationsSql);
    return r.recordset?.[0]?.inserted === 1;
  } catch (err) {
    log.error('insertNotificationOnce failed: ' + err.message);
    return false;
  }
}

// Position-based notifications — Practo style. Every time the queue moves,
// the top-3 waiting patients get a position milestone push (once per milestone
// per appointment, idempotency via insertNotificationOnce):
//   Position 1 → "You're Next!"
//   Position 2 → "Get Ready! — 2nd in line"
//   Position 3 → "3rd in Queue"
// appointment_id → queue_id subquery used to scope to exact clinic's queue;
// avoids assuming dq.clinic_id column exists.
async function sendPositionNotifications(doctor_id, appointment_id) {
  if (!doctor_id || !appointment_id) return;
  try {
    const r = await db.request()
      .input('ref_apt_id', sql.Int, parseInt(appointment_id))
      .query(`
        SELECT TOP 3
          a.appointment_id,
          ROW_NUMBER() OVER (ORDER BY a.queue_number) AS position,
          CASE WHEN a.user_type = 1 THEN p.token  ELSE ph.token       END AS token,
          CASE WHEN a.user_type = 1 THEN p.patient_id ELSE ph.patient_id END AS patient_id,
          d.name AS doctor_name
        FROM appointments a
        JOIN doctor_queue   dq ON dq.queue_id   = a.queue_id
        JOIN doctor_login   d  ON d.doctor_id   = dq.doctor_id
        LEFT JOIN patients  p  ON a.user_type = 1 AND p.patient_id  = a.patient_id
        LEFT JOIN family_members fm ON a.user_type = 2 AND fm.member_id = a.patient_id
        LEFT JOIN patients  ph ON a.user_type = 2 AND ph.patient_id = fm.family_id
        WHERE a.queue_id = (SELECT TOP 1 queue_id FROM appointments WHERE appointment_id = @ref_apt_id)
          AND a.status = 'booked'
        ORDER BY a.queue_number ASC
      `);

    const rows = r.recordset || [];
    if (rows.length === 0) return;

    for (const row of rows) {
      const pos = Number(row.position);
      const doctor = row.doctor_name || 'your doctor';
      const patient_id = row.patient_id;
      const aptId = row.appointment_id;
      const token = row.token;
      if (!patient_id || !aptId) continue;

      let stage, title, body;
      if (pos === 1) {
        stage = 'queue_next'; title = "You're Next!";
        body = `Dr. ${doctor} is ready for you. Please come in.`;
      } else if (pos === 2) {
        stage = 'queue_ready'; title = 'Get Ready!';
        body = `You're 2nd in line for Dr. ${doctor}. Please be at the clinic.`;
      } else if (pos === 3) {
        stage = 'queue_soon'; title = '3rd in Queue';
        body = `You're 3rd in line for Dr. ${doctor}. Get ready.`;
      } else { continue; }

      const refId = `${aptId}:${stage}`;
      if (!(await insertNotificationOnce(patient_id, title, body, 'queue', refId))) continue;

      if (token && String(token).trim()) {
        await admin.messaging().send({
          token,
          notification: { title, body },
          data: { type: 'queue', stage, doctor_id: String(doctor_id), appointment_id: String(aptId) },
        }).catch(err => log.error(`FCM err (pos${pos}): ` + (err.code || err.message)));
      }
    }
  } catch (err) {
    log.error('sendPositionNotifications failed: ' + err.message);
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
async function sendProximityNotifications(doctor_id, clinic_id = null) {
  if (!doctor_id) return;
  try {
    const r = await db.request()
      .input('operation', 'QUEUE_PROXIMITY_LIST')
      .input('doctor_id', doctor_id)
      .input('clinic_id', clinic_id || null)
      .run(appointmentsSql);

    const rows = r.recordset || [];
    if (rows.length === 0) return;

    await Promise.all(rows.map(async (row) => {
      const minutes = row.est_minutes_to_turn;
      const patient_id = row.owner_id;
      const token = row.owner_token;
      const aptId = row.appointment_id;
      const doctor = row.doctor_name || 'your doctor';
      if (!patient_id || !aptId || minutes == null) return;

      let stage, title, body;
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
      if (!(await insertNotificationOnce(patient_id, title, body, 'queue', refId))) return;

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

module.exports = {
  emitQueueUpdate,
  STALE_REPLAY_MS,
  isStaleReplay,
  fetchCurrentServing,
  insertNotification,
  insertNotificationForToken,
  insertNotificationOnce,
  insertNotificationsForTokens,
  notifyTokensInBackground,
  sendPositionNotifications,
  sendProximityNotifications,
  formatApptDate,
  formatApptTime,
};
