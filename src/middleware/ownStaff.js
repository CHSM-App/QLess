// Clinic staff may only touch their own doctor's data (IMPROVEMENT_PLAN.md S3,
// staff half — ownPatient.js is the patient half).
//
// A doctor token (uid = doctor_id) acts for that doctor; a receptionist token
// (uid = recep_id) acts for the doctor they work for. Every doctor_id /
// clinic_id / queue_id / appointment_id / slot_id / availability_id /
// leave_id / recep_id / patient_id in the URL, body or query must belong to
// that doctor. Patient and admin tokens pass through unchanged.
//
// A doctor blocked by an admin (doctor_login.active_status <> 0) — and their
// receptionists — get 403 DOCTOR_BLOCKED on every staff route. Verification
// (is_verified) is reviewed by an admin in the background and never restricts.
//
// Install on a router whose mount already authenticated the token:
//   require('…/ownStaff')(router)
// or inline after `auth` where a router authenticates per route:
//   router.post('/x', auth, authorize(...), ownStaff.check, handler)
const db = require('../db');
const { ROLE } = require('./roles');

// @v = the id, @d = the staff member's doctor. Tagged so tests can answer them.
const OWNS_SQL = {
  clinic_id: `SELECT 1 AS ok WHERE EXISTS (SELECT 1 FROM clinics WHERE clinic_id = @v AND doctor_id = @d)
              OR EXISTS (SELECT 1 FROM doctor_login WHERE clinic_id = @v AND doctor_id = @d)`,
  queue_id: 'SELECT 1 AS ok FROM doctor_queue WHERE queue_id = @v AND doctor_id = @d',
  appointment_id: 'SELECT 1 AS ok FROM appointments WHERE appointment_id = @v AND doctor_id = @d',
  slot_id: `SELECT 1 AS ok FROM doctor_time_slots s JOIN doctor_availability a ON a.availability_id = s.availability_id
            WHERE s.slot_id = @v AND a.doctor_id = @d`,
  availability_id: 'SELECT 1 AS ok FROM doctor_availability WHERE availability_id = @v AND doctor_id = @d',
  leave_id: 'SELECT 1 AS ok FROM doctor_leave WHERE leave_id = @v AND doctor_id = @d',
  recep_id: 'SELECT 1 AS ok FROM receptionist WHERE recep_id = @v AND doctor_id = @d',
  // a patient (or family member) who has an appointment with this doctor
  patient_id: 'SELECT TOP 1 1 AS ok FROM appointments WHERE patient_id = @v AND doctor_id = @d',
  // staff see only the prescriptions their own doctor wrote
  prescription_id: 'SELECT 1 AS ok FROM patient_records WHERE prescription_id = @v AND doctor_id = @d',
};
// Walk-in books patients who may never have seen this doctor before.
const PATIENT_FREE = /^\/walkInBook$/;

const isStaff = (req) => [ROLE.DOCTOR, ROLE.RECEPTIONIST].includes(Number(req.user && req.user.role_id));

/** The doctor this token acts for (cached on the request), or null. */
async function staffDoctorId(req) {
  if (req._staffDoctorId !== undefined) return req._staffDoctorId;
  const uid = Number(req.user.uid);
  let doctorId = null;
  if (uid > 0 && Number(req.user.role_id) === ROLE.DOCTOR) doctorId = uid;
  if (uid > 0 && Number(req.user.role_id) === ROLE.RECEPTIONIST) {
    const r = await db.request().input('v', uid)
      .query(`/* ownership */ SELECT r.doctor_id,
                (SELECT MAX(d.active_status) FROM doctor_login d WHERE d.doctor_id = r.doctor_id) AS active_status
              FROM receptionist r WHERE r.recep_id = @v AND r.active_status = 1`);
    const row = r.recordset[0];
    doctorId = Number(row && row.doctor_id) || null;
    if (doctorId) req._staffActive = Number(row.active_status) === 0;
  }
  req._staffDoctorId = doctorId;
  return doctorId;
}

/** False when an admin has blocked the doctor this staff token acts for. */
async function staffActive(req) {
  const doctorId = await staffDoctorId(req);
  if (!doctorId) return true; // no doctor yet: the id checks answer 401 where it matters
  if (req._staffActive === undefined) {
    const r = await db.request().input('v', doctorId)
      .query('/* ownership */ SELECT MAX(active_status) AS active_status FROM doctor_login WHERE doctor_id = @v');
    const row = r.recordset[0];
    // active_status 0 = active; a missing doctor row counts as blocked
    req._staffActive = !!row && row.active_status !== null && row.active_status !== undefined && Number(row.active_status) === 0;
  }
  return req._staffActive;
}

const BLOCKED = { code: 'DOCTOR_BLOCKED', msg: 'Your account has been blocked. Please contact support.' };

async function owns(name, v, doctorId) {
  if (name === 'doctor_id') return v === doctorId;
  const r = await db.request().input('v', v).input('d', doctorId).query(`/* ownership */ ${OWNS_SQL[name]}`);
  return r.recordset.length > 0;
}

const NAMES = ['doctor_id', ...Object.keys(OWNS_SQL)];
const absent = (raw) => raw === undefined || raw === null || raw === '' || raw === 'null' || Number(raw) === 0;

/** Checks one id; answers 401/403 itself and returns false when not allowed. */
async function checkOne(req, res, name, raw) {
  if (absent(raw)) return true; // the route validates required fields itself
  if (name === 'patient_id' && PATIENT_FREE.test(req.path)) return true;
  const doctorId = await staffDoctorId(req);
  if (!doctorId) { res.status(401).json({ msg: 'Session is out of date. Please sign in again.' }); return false; }
  // clinic ids are strings (CL001); every other id is numeric
  const v = name === 'clinic_id' ? String(raw) : Number(raw);
  if ((name !== 'clinic_id' && !Number.isInteger(v)) || !(await owns(name, v, doctorId))) {
    res.status(403).json({ msg: "You can only access your own clinic's records." });
    return false;
  }
  return true;
}

/** Inline middleware: blocked check + params + body + query. */
async function check(req, res, next) {
  if (!isStaff(req)) return next();
  try {
    if (!(await staffActive(req))) return res.status(403).json(BLOCKED);
    for (const src of [req.params || {}, req.body || {}, req.query || {}]) {
      for (const name of NAMES) {
        if (name in src && !(await checkOne(req, res, name, src[name]))) return undefined;
      }
    }
    return next();
  } catch (err) { return next(err); }
}

/** URL ids only — for sub-routers whose parent already installed ownStaff(). */
function params(router) {
  for (const name of NAMES) {
    router.param(name, async (req, res, next, value) => {
      if (!isStaff(req)) return next();
      try { return (await checkOne(req, res, name, value)) ? next() : undefined; } catch (err) { return next(err); }
    });
  }
}

function ownStaff(router) {
  // blocked check + body / query (params are not parsed yet here)
  router.use(async (req, res, next) => {
    if (!isStaff(req)) return next();
    try {
      if (!(await staffActive(req))) return res.status(403).json(BLOCKED);
      for (const src of [req.body || {}, req.query || {}]) {
        for (const name of NAMES) {
          if (name in src && !(await checkOne(req, res, name, src[name]))) return undefined;
        }
      }
      return next();
    } catch (err) { return next(err); }
  });
  params(router);
}

module.exports = ownStaff;
module.exports.params = params;
module.exports.check = check;
module.exports.owns = owns;
module.exports.isStaff = isStaff;
module.exports.staffDoctorId = staffDoctorId;
