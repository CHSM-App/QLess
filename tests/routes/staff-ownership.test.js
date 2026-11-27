const request = require('supertest');
const jwt = require('jsonwebtoken');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

// S3 (staff half): a doctor token (uid = doctor_id) or a receptionist token
// (works for one doctor) may only touch that doctor's records.
const doctor1 = () => authHeader({ role_id: ROLE.DOCTOR, uid: 1 });
const recep = () => authHeader({ role_id: ROLE.RECEPTIONIST, uid: 7 }); // works for doctor 1 (mock staffDoctorId)
const blocked = (res) => expect(res.status).toBe(403);
const allowed = (res) => expect([401, 403]).not.toContain(res.status);

beforeEach(() => { mockDb.reset(); mockDb.respond = () => [{ success: 1 }]; });

describe("another doctor's doctor_id", () => {
  test.each([
    ['get', '/doctor/users/getAllMedicines/2'],
    ['get', '/doctor/users/appointment/getTodayQueue/2'],
    ['get', '/doctor/users/patientAppointmentList/2'],
    ['get', '/doctor/users/fetchReceptionistList/2'],
    ['get', '/doctor/insert/doctorLeaves/2/CL001'],
    ['delete', '/doctor/index/deleteMedicine/2/7'],
  ])('%s %s → 403, nothing read', async (method, url) => {
    blocked(await request(app)[method](url).set(doctor1()));
    expect(mockDb.calls).toHaveLength(0);
  });

  test('in the body (queue actions) → 403', async () => {
    blocked(await request(app).post('/doctor/insert/appointment/queueStart').set(doctor1()).send({ doctor_id: 2, queue_id: 5 }));
    blocked(await request(app).post('/doctor/insert/addDoctorLeave').set(doctor1()).send({ doctor_id: 2, from_date: '2026-12-01', to_date: '2026-12-01' }));
    expect(mockDb.calls).toHaveLength(0);
  });

  test('own doctor_id passes', async () => {
    allowed(await request(app).get('/doctor/users/getAllMedicines/1').set(doctor1()));
    allowed(await request(app).get('/doctor/users/fetchReceptionistList/1').set(doctor1()));
  });
});

describe('ids owned through the doctor (looked up)', () => {
  test.each([
    ['queue', '/doctor/insert/appointment/queueStart', { doctor_id: 1, queue_id: 99 }],
    ['appointment', '/doctor/insert/appointment/queueNext', { doctor_id: 1, appointment_id: 99 }],
    ['leave', '/doctor/insert/cancelDoctorLeave', { doctor_id: 1, leave_id: 99 }],
    ['clinic', '/doctor/insert/addQueueStartTime/', { doctor_id: 1, clinic_id: 'CL999', q_start_before: 5 }],
  ])("another doctor's %s → 403", async (_, url, body) => {
    mockDb.owns = false;
    blocked(await request(app).post(url).set(doctor1()).send(body));
    expect(mockDb.calls).toHaveLength(0);
  });

  test('URL ids too: emergency pause of a foreign queue → 403', async () => {
    mockDb.owns = false;
    blocked(await request(app).post('/doctor/insert/appointment/queuePauseEmergency/99').set(doctor1()));
  });

  test('clinic routes under /login are guarded as well', async () => {
    mockDb.owns = false;
    blocked(await request(app).delete('/login/deleteClinic/CL999/1').set(doctor1()));
    blocked(await request(app).delete('/login/deleteClinic/CL001/2').set(doctor1()));
  });
});

describe('receptionists', () => {
  test("act for their doctor only", async () => {
    allowed(await request(app).post('/doctor/insert/appointment/queueStop').set(recep()).send({ doctor_id: 1, queue_id: 5 }));
    blocked(await request(app).post('/doctor/insert/appointment/queueStop').set(recep()).send({ doctor_id: 2, queue_id: 5 }));
  });

  test('walk-in may book any registered patient (no patient_id ownership)', async () => {
    mockDb.respond = ({ inputs }) => (inputs.operation === 'IS_BLOCKED' ? [{ blocked: 0 }]
      : inputs.operation === 'BOOK' ? [{ success: 1, message: 'Booked' }] : []);
    const res = await request(app).post('/doctor/insert/walkInBook').set(recep())
      .send({ name: 'A', mobile_no: '9000011111', doctor_id: 1, appointment_date: '2026-11-20', patient_id: 555 });
    allowed(res);
  });

  test('a receptionist no longer working (not found) → 401', async () => {
    mockDb.staffDoctorId = null;
    expect((await request(app).post('/doctor/insert/appointment/queueStop').set(recep()).send({ doctor_id: 1, queue_id: 5 })).status).toBe(401);
  });

  test('a staff token without uid → 401', async () => {
    const t = jwt.sign({ role_id: ROLE.DOCTOR }, process.env.JWT_SECRET_KEY);
    expect((await request(app).get('/doctor/users/getAllMedicines/1').set('Authorization', `Bearer ${t}`)).status).toBe(401);
  });
});

describe('patients on /doctor/users', () => {
  const patient = () => authHeader({ role_id: ROLE.PATIENT, uid: 4 });

  test.each(['/doctor/users/patientAppointmentList/1', '/doctor/users/appointment/getTodayQueue/1',
    '/doctor/users/fetchReceptionistList/1', '/doctor/users/getAllMedicines/1'])('%s → 403 for a patient', async (url) => {
    blocked(await request(app).get(url).set(patient()));
  });

  test('clinic photos stay open; prescription only for their own appointment', async () => {
    allowed(await request(app).get('/doctor/users/clinicGallery/CL001').set(patient()));
    allowed(await request(app).get('/doctor/users/appointmentWisePrescription/10').set(patient()));
    mockDb.owns = false;
    blocked(await request(app).get('/doctor/users/appointmentWisePrescription/10').set(patient()));
  });
});

test('fetchReceptionistList works (regression: it once called an undefined logger)', async () => {
  mockDb.respond = () => [{ recep_id: 7, name: 'Meera' }];
  const res = await request(app).get('/doctor/users/fetchReceptionistList/1').set(doctor1());
  expect(res.status).toBe(200);
  expect(res.body).toEqual([{ recep_id: 7, name: 'Meera' }]);
});

test('Content-Security-Policy: no inline scripts, page scripts served from /static', async () => {
  const page = await request(app).get('/admin');
  expect(page.headers['content-security-policy']).toMatch(/script-src 'self'(;|$)/);
  expect(page.text).not.toMatch(/<script>/);
  const js = await request(app).get('/static/admin-panel.js');
  expect(js.status).toBe(200);
  expect(js.headers['content-type']).toMatch(/javascript/);
});
