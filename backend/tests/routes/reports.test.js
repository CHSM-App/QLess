const os = require('os');
const path = require('path');
process.env.UPLOADS_DIR = path.join(os.tmpdir(), `qless-reports-test-${process.pid}`);
process.env.ANTHROPIC_API_KEY = 'test-key';

const request = require('supertest');
const fs = require('fs-extra');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');

jest.mock('../../src/ai', () => {
  const actual = jest.requireActual('../../src/ai');
  return { ...actual, summarizeReport: jest.fn() };
});
const ai = require('../../src/ai');
const app = require('../../src/server');

const doctor = () => authHeader({ role_id: ROLE.DOCTOR, uid: 1 });
const patient = (uid = 4) => authHeader({ role_id: ROLE.PATIENT, uid });
const PNG = Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex');
const PDF = Buffer.from('%PDF-1.4\n1 0 obj << /Type /Page >> endobj\n%%EOF');
const SUMMARY = { patient_name: 'Asha', report_type: 'CBC', report_date: '', overview: 'ok', key_findings: [], notes: [] };

// Answers the queries reports.js makes; `rows` holds medical_reports rows.
function fakeDb({ count = 0, dup = null, rows = [] } = {}) {
  mockDb.respond = ({ target, inputs }) => {
    if (target.includes('COUNT(*) AS n FROM medical_reports')) return [{ n: count }];
    if (target.includes('SELECT TOP 1 summary')) return dup ? [{ summary: JSON.stringify(dup) }] : [];
    if (target.includes('INSERT INTO medical_reports')) {
      rows.push({ report_id: 10, file_names: inputs.file_names, summary: inputs.summary, doctor_id: inputs.doctor_id,
        patient_id: inputs.patient_id, user_type: inputs.user_type, uploaded_by_role: inputs.role, uploaded_by_id: inputs.uid });
      return [{ report_id: 10 }];
    }
    if (target.includes('WHERE r.report_id = @id')) return rows.filter((r) => r.report_id === inputs.id);
    return [];
  };
}

beforeEach(() => {
  mockDb.reset();
  ai.summarizeReport.mockReset();
  ai.summarizeReport.mockResolvedValue({ summary: SUMMARY, usage: { input_tokens: 5000, output_tokens: 400 } });
  delete process.env.AI_REPORTS_ENABLED;
});
afterAll(() => fs.remove(process.env.UPLOADS_DIR));

const upload = (who, files, fields = {}) => {
  let req = request(app).post('/reports/summarize').set(who);
  for (const [k, v] of Object.entries(fields)) req = req.field(k, String(v));
  for (const [buf, name, type] of files) req = req.attach('files', buf, { filename: name, contentType: type });
  return req;
};

describe('POST /reports/summarize', () => {
  test('doctor upload without patient is saved unassigned, tokens recorded', async () => {
    fakeDb();
    const res = await upload(doctor(), [[PNG, 'a.png', 'image/png'], [PNG, 'b.png', 'image/png']]);
    expect(res.status).toBe(201);
    expect(res.body.report).toMatchObject({ report_id: 10, patient_id: null, files: ['image', 'image'], summary: SUMMARY });
    const ins = mockDb.callsTo('INSERT INTO medical_reports')[0].inputs;
    expect(ins).toMatchObject({ doctor_id: 1, patient_id: null, input_tokens: 5000, output_tokens: 400 });
    expect(ai.summarizeReport).toHaveBeenCalledWith(expect.any(Array), 'doctor');
  });

  test('identical upload reuses the stored summary — no Claude call', async () => {
    fakeDb({ dup: SUMMARY });
    const res = await upload(doctor(), [[PDF, 'r.pdf', 'application/pdf']]);
    expect(res.status).toBe(201);
    expect(ai.summarizeReport).not.toHaveBeenCalled();
    expect(mockDb.callsTo('INSERT INTO medical_reports')[0].inputs).toMatchObject({ input_tokens: null, output_tokens: null });
  });

  test('daily cap → 429 before upload or Claude', async () => {
    fakeDb({ count: ai.DAILY_LIMIT.patient });
    const res = await upload(patient(), [[PNG, 'a.png', 'image/png']]);
    expect(res.status).toBe(429);
    expect(ai.summarizeReport).not.toHaveBeenCalled();
  });

  test('kill switch → 503', async () => {
    process.env.AI_REPORTS_ENABLED = 'false';
    const res = await upload(doctor(), [[PNG, 'a.png', 'image/png']]);
    expect(res.status).toBe(503);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('photos and a PDF together → 400', async () => {
    fakeDb();
    const res = await upload(doctor(), [[PNG, 'a.png', 'image/png'], [PDF, 'r.pdf', 'application/pdf']]);
    expect(res.status).toBe(400);
    expect(ai.summarizeReport).not.toHaveBeenCalled();
  });

  test('patient upload defaults to self with patient wording', async () => {
    fakeDb();
    const res = await upload(patient(4), [[PNG, 'a.png', 'image/png']]);
    expect(res.status).toBe(201);
    expect(mockDb.callsTo('INSERT INTO medical_reports')[0].inputs).toMatchObject({ doctor_id: null, patient_id: 4, user_type: 1 });
    expect(ai.summarizeReport).toHaveBeenCalledWith(expect.any(Array), 'patient');
  });

  test("patient can't upload for someone else", async () => {
    fakeDb();
    const res = await upload(patient(4), [[PNG, 'a.png', 'image/png']], { patient_id: 9, user_type: 1 });
    expect(res.status).toBe(403);
  });
});

describe('access', () => {
  const row = { report_id: 5, doctor_id: 1, patient_id: 4, user_type: 1, file_names: '["x.png"]', summary: '{}',
    uploaded_by_role: ROLE.DOCTOR, uploaded_by_id: 1 };

  test("another patient's report → 403", async () => {
    fakeDb({ rows: [row] });
    expect((await request(app).get('/reports/5/file/0').set(patient(8))).status).toBe(403);
  });

  test("another doctor's report → 403", async () => {
    fakeDb({ rows: [{ ...row, doctor_id: 2 }] });
    expect((await request(app).put('/reports/5/assign').set(doctor()).send({ patient_id: 4 })).status).toBe(403);
  });

  test("patient can't delete a doctor's report", async () => {
    fakeDb({ rows: [row] });
    expect((await request(app).delete('/reports/5').set(patient(4))).status).toBe(403);
  });

  test('report files are not served from /uploads', async () => {
    expect((await request(app).get('/uploads/reports/x.png').set(doctor())).status).toBe(404);
  });
});

describe('patient report shared via a prescription', () => {
  test("is stored under the prescribing doctor; that doctor can't move or delete it", async () => {
    const rows = [];
    fakeDb({ rows });
    const base = mockDb.respond;
    mockDb.respond = (call) => (call.target.includes('SELECT doctor_id FROM patient_records') ? [{ doctor_id: 1 }] : base(call));
    const res = await upload(patient(4), [[PNG, 'a.png', 'image/png']], { prescription_id: 77 });
    expect(res.status).toBe(201);
    expect(mockDb.callsTo('INSERT INTO medical_reports')[0].inputs).toMatchObject({ doctor_id: 1, patient_id: 4, prescription_id: 77 });
    expect(res.body.report.uploaded_by_patient).toBe(true);
    expect((await request(app).put('/reports/10/assign').set(doctor()).send({ patient_id: 4 })).status).toBe(403);
    expect((await request(app).delete('/reports/10').set(doctor())).status).toBe(403);
  });
});
