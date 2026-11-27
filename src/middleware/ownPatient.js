// Patients may only touch their own records (IMPROVEMENT_PLAN.md S3).
//
// Patient routes take patient_id / family_id / appointment_id … straight from
// the URL or body, so any signed-in patient could read or change anyone's
// favorites, reviews, family, appointments and prescriptions. For a patient
// token (uid = patient_id) every such id is checked here; doctor, receptionist
// and admin tokens pass through unchanged.
//
// Install on a router before its routes: require('…/ownPatient')(router).
const db = require('../db');
const { ROLE } = require('./roles');

// Routes where patient_id may also be one of the caller's family members
// (family bookings, reviews and arrivals are stored under the member's id).
const MEMBER_OK = /^\/(appointment\/book|review\/add|appointment\/markArrived|review\/[^/]+\/[^/]+)$/;

// SQL ownership checks; @v = the id, @uid = the patient. Tagged so tests can answer them.
const OWNS_SQL = {
  member: 'SELECT 1 AS ok FROM family_members WHERE member_id = @v AND family_id = @uid',
  appointment: `SELECT 1 AS ok FROM appointments a WHERE a.appointment_id = @v AND (
      (ISNULL(a.user_type, 1) <> 2 AND a.patient_id = @uid)
      OR (a.user_type = 2 AND EXISTS (SELECT 1 FROM family_members fm WHERE fm.member_id = a.patient_id AND fm.family_id = @uid)))`,
  prescription: `SELECT 1 AS ok FROM patient_records r WHERE r.prescription_id = @v AND (
      (ISNULL(r.user_type, 1) <> 2 AND r.patient_id = @uid)
      OR (r.user_type = 2 AND EXISTS (SELECT 1 FROM family_members fm WHERE fm.member_id = r.patient_id AND fm.family_id = @uid)))`,
  notification: 'SELECT 1 AS ok FROM notifications WHERE notification_id = @v AND patient_id = @uid',
};
async function owns(kind, v, uid) {
  const r = await db.request().input('v', v).input('uid', uid).query(`/* ownership */ ${OWNS_SQL[kind]}`);
  return r.recordset.length > 0;
}

const CHECKS = {
  family_id: async (v, uid) => v === uid,
  reviewed_by_user_id: async (v, uid) => v === uid,
  patient_id: async (v, uid, req) => v === uid ||
    (MEMBER_OK.test(req.path) && Number(req.body?.user_type) !== 1 && owns('member', v, uid)),
  member_id: (v, uid) => owns('member', v, uid),
  appointment_id: (v, uid) => owns('appointment', v, uid),
  prescription_id: (v, uid) => owns('prescription', v, uid),
  notification_id: (v, uid) => owns('notification', v, uid),
};

const isPatient = (req) => Number(req.user && req.user.role_id) === ROLE.PATIENT;

async function check(req, res, name, raw) {
  if (raw === undefined || raw === null || raw === '' || Number(raw) === 0) return true; // absent: the route validates
  const uid = Number(req.user.uid);
  if (!uid) { res.status(401).json({ msg: 'Session is out of date. Please sign in again.' }); return false; }
  const v = Number(raw);
  if (!Number.isInteger(v) || !(await CHECKS[name](v, uid, req))) {
    res.status(403).json({ msg: 'You can only access your own records.' });
    return false;
  }
  return true;
}

module.exports = ownPatient;
module.exports.owns = owns;

function ownPatient(router) {
  // body / query ids (params are not parsed yet at this point)
  router.use(async (req, res, next) => {
    if (!isPatient(req)) return next();
    try {
      for (const src of [req.body || {}, req.query || {}]) {
        for (const name of Object.keys(CHECKS)) {
          if (name in src && !(await check(req, res, name, src[name]))) return undefined;
        }
      }
      return next();
    } catch (err) { return next(err); }
  });
  // URL ids
  for (const name of Object.keys(CHECKS)) {
    router.param(name, async (req, res, next, value) => {
      if (!isPatient(req)) return next();
      try { return (await check(req, res, name, value)) ? next() : undefined; } catch (err) { return next(err); }
    });
  }
}
