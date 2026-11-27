// /reports — AI summaries of medical reports (photos or one PDF).
//
// Doctor / receptionist: summarise, keep unassigned (inbox) or attach to a
// patient and optionally one of that patient's prescriptions, assign later.
// Patient: summarise their own (or a family member's) reports and see every
// report attached to them, including the doctor's.
//
// Visibility: staff see rows with their doctor's doctor_id; patients see rows
// whose patient_id is them or their family member. Patient self-uploads have
// doctor_id NULL — unless attached to a prescription, then they are shared
// with the doctor who wrote it.
//
// Credit usage: see src/ai.js. Undo: ROLLBACK_AI_REPORTS.md.
const express = require('express');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs-extra');
const db = require('../db');
const log = require('../middleware/logger');
const { ROLE } = require('../middleware/roles');
const ownStaff = require('../middleware/ownStaff');
const ownPatient = require('../middleware/ownPatient');
const { reportUpload, uploadHandler, verifyReportFiles, cleanupFiles } = require('../middleware/upload');
const ai = require('../ai');

const router = express.Router();
// Staff: patient_id / prescription_id in URL or JSON body must be their doctor's.
ownStaff(router);

const REPORTS_DIR = path.join(require('../uploads'), 'reports');
const EXT = { 'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp', 'application/pdf': '.pdf' };

const num = (v) => (Number.isInteger(Number(v)) && Number(v) > 0 ? Number(v) : null);
const userTypeOf = (v) => (Number(v) === 2 ? 2 : 1);

// Who is calling: { patient, uid, role, doctorId? }, or null (admin etc.).
async function caller(req) {
  const role = Number(req.user.role_id);
  const uid = Number(req.user.uid);
  if (role === ROLE.PATIENT) return { patient: true, uid, role };
  if (ownStaff.isStaff(req)) return { patient: false, uid, role, doctorId: await ownStaff.staffDoctorId(req) };
  return null;
}

// Every route: resolve the caller once.
router.use(async (req, res, next) => {
  try {
    req.caller = await caller(req);
    if (!req.caller || (!req.caller.patient && !req.caller.doctorId)) {
      return res.status(403).json({ success: false, error: 'Not allowed.' });
    }
    return next();
  } catch (err) { return next(err); }
});

// patient_id is the patient themself (user_type 1) or one of their family members (2).
const patientOwns = (uid, patientId, userType) =>
  userTypeOf(userType) === 2 ? ownPatient.owns('member', patientId, uid) : Promise.resolve(patientId === uid);

// The prescription's row if it belongs to this patient, else undefined.
async function prescriptionFor(prescriptionId, patientId, userType) {
  const r = await db.request()
    .input('p', prescriptionId).input('pt', patientId).input('ut', userTypeOf(userType))
    .query('SELECT doctor_id FROM patient_records WHERE prescription_id = @p AND patient_id = @pt AND ISNULL(user_type, 1) = @ut');
  return r.recordset[0];
}

const SELECT = `SELECT r.report_id, r.doctor_id, r.patient_id, r.user_type, r.prescription_id,
    r.uploaded_by_role, r.uploaded_by_id, r.file_names, r.summary, r.created_at,
    (SELECT TOP 1 d.name FROM doctor_login d WHERE d.doctor_id = r.doctor_id) AS doctor_name,
    CASE WHEN r.user_type = 2 THEN (SELECT fm.name FROM family_members fm WHERE fm.member_id = r.patient_id)
         ELSE (SELECT p.name FROM Patients p WHERE p.patient_id = r.patient_id) END AS patient_name
  FROM medical_reports r`;

function toJson(row) {
  const files = JSON.parse(row.file_names || '[]');
  let summary = {};
  try { summary = JSON.parse(row.summary || '{}'); } catch { /* keep {} */ }
  return {
    report_id: row.report_id,
    doctor_id: row.doctor_id,
    doctor_name: row.doctor_name || null,
    patient_id: row.patient_id,
    user_type: row.user_type,
    patient_name: row.patient_name || null,
    prescription_id: row.prescription_id,
    uploaded_by_patient: row.uploaded_by_role === ROLE.PATIENT,
    created_at: row.created_at,
    files: files.map((f) => (f.endsWith('.pdf') ? 'pdf' : 'image')),
    summary,
  };
}

async function list(where, inputs) {
  const request = db.request();
  for (const [k, v] of Object.entries(inputs)) request.input(k, v);
  const r = await request.query(`${SELECT} WHERE ${where} ORDER BY r.created_at DESC`);
  return r.recordset.map(toJson);
}

// Loads a report the caller may see; answers 404/403 itself and returns null then.
async function loadReport(req, res) {
  const id = num(req.params.report_id);
  const r = id && await db.request().input('id', id).query(`${SELECT} WHERE r.report_id = @id`);
  const row = r && r.recordset[0];
  if (!row) { res.status(404).json({ success: false, error: 'Report not found.' }); return null; }
  const c = req.caller;
  const ok = c.patient
    ? row.patient_id != null && await patientOwns(c.uid, row.patient_id, row.user_type)
    : row.doctor_id === c.doctorId;
  if (!ok) { res.status(403).json({ success: false, error: 'You can only access your own reports.' }); return null; }
  return row;
}

const fail = (res, where) => (err) => {
  log.error(`reports ${where}: ${err.message}`);
  if (!res.headersSent) res.status(500).json({ success: false, error: 'Something went wrong.' });
};

// ── POST /reports/summarize — multipart `files` (1–6 photos or 1 PDF),
// optional patient_id, user_type, prescription_id.
// Order matters for credits: kill switch → daily cap → upload → checks →
// duplicate lookup → Claude (only if nothing matched) → save.
router.post('/summarize', async (req, res, next) => {
  try {
    if (!ai.enabled()) return res.status(503).json({ success: false, error: 'AI summary is turned off.' });
    const c = req.caller;
    const r = await db.request().input('uid', c.uid).input('role', c.role)
      .query(`SELECT COUNT(*) AS n FROM medical_reports
              WHERE uploaded_by_id = @uid AND uploaded_by_role = @role AND created_at >= CAST(GETDATE() AS date)`);
    const limit = c.patient ? ai.DAILY_LIMIT.patient : ai.DAILY_LIMIT.staff;
    if (Number(r.recordset[0]?.n) >= limit) {
      return res.status(429).json({ success: false, error: `Daily limit of ${limit} report summaries reached. Try again tomorrow.` });
    }
    // Whatever happens next, temp uploads never outlive the response (moved files are already gone).
    res.on('finish', () => cleanupFiles(req).catch(() => {}));
    return next();
  } catch (err) { return fail(res, 'summarize precheck')(err); }
}, uploadHandler(reportUpload.array('files')), ownStaff.check, async (req, res) => {
  const c = req.caller;
  try {
    if (!(await verifyReportFiles(req, res))) return;
    const files = req.files;

    let patientId = num(req.body.patient_id);
    let userType = patientId ? userTypeOf(req.body.user_type) : null;
    const prescriptionId = num(req.body.prescription_id);
    if (c.patient) {
      if (!patientId) { patientId = c.uid; userType = 1; }
      if (!(await patientOwns(c.uid, patientId, userType))) {
        return res.status(403).json({ success: false, error: 'You can only add your own reports.' });
      }
    }
    // ownStaff.check already tied patient_id / prescription_id to this doctor.
    const rx = prescriptionId && patientId ? await prescriptionFor(prescriptionId, patientId, userType) : null;
    if (prescriptionId && !rx) {
      return res.status(400).json({ success: false, error: 'That prescription does not belong to this patient.' });
    }
    // A patient's report attached to a prescription is shared with the doctor who wrote it.
    const doctorId = c.patient ? (rx ? rx.doctor_id : null) : c.doctorId;

    const hash = crypto.createHash('sha256');
    for (const f of files) hash.update(await fs.readFile(f.path));
    const fileHash = hash.digest('hex');

    // Same files uploaded before by the same side → reuse that summary, no Claude call.
    const dup = await db.request().input('h', fileHash).input('d', c.doctorId || 0).input('uid', c.uid)
      .query(`SELECT TOP 1 summary FROM medical_reports
              WHERE file_hash = @h AND file_names <> '[]' AND (
                (@d <> 0 AND doctor_id = @d AND uploaded_by_role <> ${ROLE.PATIENT})
                OR (@d = 0 AND uploaded_by_role = ${ROLE.PATIENT} AND uploaded_by_id = @uid))
              ORDER BY report_id DESC`);
    let summary = dup.recordset[0]?.summary;
    let usage = { input_tokens: null, output_tokens: null };
    if (!summary) {
      try {
        const out = await ai.summarizeReport(files, c.patient ? 'patient' : 'doctor');
        summary = JSON.stringify(out.summary);
        usage = out.usage;
      } catch (err) {
        if (err instanceof ai.AiError) return res.status(err.status).json({ success: false, error: err.message });
        throw err;
      }
    }

    await fs.ensureDir(REPORTS_DIR);
    const names = files.map((f) => crypto.randomUUID() + EXT[f.realType]);
    await Promise.all(files.map((f, i) => fs.move(f.path, path.join(REPORTS_DIR, names[i]))));
    try {
      const ins = await db.request()
        .input('doctor_id', doctorId)
        .input('patient_id', patientId)
        .input('user_type', userType)
        .input('prescription_id', prescriptionId)
        .input('role', c.role)
        .input('uid', c.uid)
        .input('file_names', JSON.stringify(names))
        .input('summary', summary)
        .input('file_hash', fileHash)
        .input('input_tokens', usage.input_tokens)
        .input('output_tokens', usage.output_tokens)
        .query(`INSERT INTO medical_reports (doctor_id, patient_id, user_type, prescription_id, uploaded_by_role,
                  uploaded_by_id, file_names, summary, file_hash, input_tokens, output_tokens)
                OUTPUT INSERTED.report_id
                VALUES (@doctor_id, @patient_id, @user_type, @prescription_id, @role, @uid, @file_names, @summary,
                  @file_hash, @input_tokens, @output_tokens)`);
      req.params.report_id = ins.recordset[0].report_id;
    } catch (err) {
      await Promise.allSettled(names.map((n) => fs.remove(path.join(REPORTS_DIR, n))));
      throw err;
    }
    const row = await loadReport(req, res);
    if (row) res.status(201).json({ success: true, report: toJson(row) });
  } catch (err) { fail(res, 'summarize')(err); }
});

// ── GET /reports/unassigned — the doctor's inbox.
router.get('/unassigned', async (req, res) => {
  if (req.caller.patient) return res.status(403).json({ success: false, error: 'Not allowed.' });
  list('r.doctor_id = @d AND r.patient_id IS NULL', { d: req.caller.doctorId })
    .then((reports) => res.json({ success: true, reports }), fail(res, 'unassigned'));
});

// ── GET /reports/patient/:patient_id?user_type=2
router.get('/patient/:patient_id', async (req, res) => {
  try {
    const c = req.caller;
    const patientId = num(req.params.patient_id);
    const userType = userTypeOf(req.query.user_type);
    if (!patientId) return res.status(400).json({ success: false, error: 'patient_id required.' });
    if (c.patient && !(await patientOwns(c.uid, patientId, userType))) {
      return res.status(403).json({ success: false, error: 'You can only access your own reports.' });
    }
    const where = 'r.patient_id = @p AND ISNULL(r.user_type, 1) = @ut' + (c.patient ? '' : ' AND r.doctor_id = @d');
    res.json({ success: true, reports: await list(where, { p: patientId, ut: userType, d: c.doctorId || 0 }) });
  } catch (err) { fail(res, 'patient')(err); }
});

// ── GET /reports/prescription/:prescription_id
router.get('/prescription/:prescription_id', async (req, res) => {
  try {
    const c = req.caller;
    const id = num(req.params.prescription_id);
    if (!id) return res.status(400).json({ success: false, error: 'prescription_id required.' });
    if (c.patient && !(await ownPatient.owns('prescription', id, c.uid))) {
      return res.status(403).json({ success: false, error: 'You can only access your own reports.' });
    }
    const where = 'r.prescription_id = @p' + (c.patient ? ' AND r.patient_id IS NOT NULL' : ' AND r.doctor_id = @d');
    res.json({ success: true, reports: await list(where, { p: id, d: c.doctorId || 0 }) });
  } catch (err) { fail(res, 'prescription')(err); }
});

// ── PUT /reports/:report_id/assign  { patient_id, user_type, prescription_id? } — staff only.
router.put('/:report_id/assign', async (req, res) => {
  try {
    if (req.caller.patient) return res.status(403).json({ success: false, error: 'Not allowed.' });
    const row = await loadReport(req, res);
    if (!row) return;
    if (row.uploaded_by_role === ROLE.PATIENT) {
      return res.status(403).json({ success: false, error: "A patient's own report can't be moved." });
    }
    const patientId = num(req.body.patient_id);
    const userType = userTypeOf(req.body.user_type);
    const prescriptionId = num(req.body.prescription_id);
    if (!patientId) return res.status(400).json({ success: false, error: 'patient_id required.' });
    if (prescriptionId && !(await prescriptionFor(prescriptionId, patientId, userType))) {
      return res.status(400).json({ success: false, error: 'That prescription does not belong to this patient.' });
    }
    await db.request().input('id', row.report_id).input('p', patientId).input('ut', userType).input('rx', prescriptionId)
      .query('UPDATE medical_reports SET patient_id = @p, user_type = @ut, prescription_id = @rx WHERE report_id = @id');
    const updated = await loadReport(req, res);
    if (updated) res.json({ success: true, report: toJson(updated) });
  } catch (err) { fail(res, 'assign')(err); }
});

// ── DELETE /reports/:report_id — each side deletes only what it uploaded
// (staff: their doctor's uploads; patient: their own).
// The row is kept but emptied (invisible to everyone): the daily cap and the
// token spend still count it, so delete-and-retry can't run up credits.
router.delete('/:report_id', async (req, res) => {
  try {
    const c = req.caller;
    const row = await loadReport(req, res);
    if (!row) return;
    const patientUpload = row.uploaded_by_role === ROLE.PATIENT;
    if (c.patient ? !(patientUpload && row.uploaded_by_id === c.uid) : patientUpload) {
      return res.status(403).json({ success: false, error: 'You can only delete reports you added.' });
    }
    await db.request().input('id', row.report_id)
      .query(`UPDATE medical_reports SET doctor_id = NULL, patient_id = NULL, prescription_id = NULL,
                file_names = '[]', summary = '{}' WHERE report_id = @id`);
    const files = JSON.parse(row.file_names || '[]');
    await Promise.allSettled(files.map((n) => fs.remove(path.join(REPORTS_DIR, n))));
    res.json({ success: true });
  } catch (err) { fail(res, 'delete')(err); }
});

// ── GET /reports/:report_id/file/:n — the n-th original page (0-based).
router.get('/:report_id/file/:n', async (req, res) => {
  try {
    const row = await loadReport(req, res);
    if (!row) return;
    const name = JSON.parse(row.file_names || '[]')[Number(req.params.n)];
    if (!name) return res.status(404).json({ success: false, error: 'File not found.' });
    res.sendFile(path.join(REPORTS_DIR, name), (err) => err && fail(res, 'file')(err));
  } catch (err) { fail(res, 'file')(err); }
});

module.exports = router;
