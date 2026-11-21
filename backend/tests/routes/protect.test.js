const request = require('supertest');
const jwt = require('jsonwebtoken');
const { mockDb } = require('../helpers/db');
const { authHeader } = require('../helpers/auth');
const app = require('../../src/server');

beforeEach(() => mockDb.reset());

// One real endpoint per JWT-protected mount.
const PROTECTED = [
  ['post', '/doctor/insert/appointment/queueNext'],
  ['get', '/doctor/users/x'],
  ['get', '/doctor/index/x'],
  ['get', '/patient/users/x'],
  ['post', '/patient/insert/x'],
  ['get', '/patient/index/x'],
];

describe('JWT-protected mounts', () => {
  test.each(PROTECTED)('%s %s → 401 without a token', async (method, url) => {
    const res = await request(app)[method](url);
    expect(res.status).toBe(401);
    expect(mockDb.calls).toHaveLength(0);
  });

  test.each(PROTECTED)('%s %s → 401 with a token signed by another key', async (method, url) => {
    const forged = jwt.sign({ role_id: 1, uid: 1 }, 'not-the-server-secret-not-the-server-secret');
    const res = await request(app)[method](url).set('Authorization', `Bearer ${forged}`);
    expect(res.status).toBe(401);
  });

  test('a valid token gets through to the route', async () => {
    const res = await request(app)
      .post('/doctor/insert/appointment/queueNext')
      .set(authHeader())
      .send({});
    expect(res.status).toBe(400); // the route's own validation, not the auth gate
  });
});

describe('/doctor/insert — clinic staff only', () => {
  const { ROLE } = require('../helpers/auth');
  const insertRouter = require('../../src/routes/doctor/insert');

  // Every route on the router (walks the sub-routers), params filled with 1.
  const routes = insertRouter.stack
    .flatMap((layer) => (layer.handle.stack || []).filter((l) => l.route))
    .flatMap((l) => Object.keys(l.route.methods).map((m) => [m, '/doctor/insert' + l.route.path.replace(/:\w+\??/g, '1')]));

  test('covers every /doctor/insert route', () => {
    expect(routes).toHaveLength(20);
  });

  test.each(routes)('%s %s → 403 for a patient, no DB call', async (method, url) => {
    const res = await request(app)[method](url).set(authHeader({ role_id: ROLE.PATIENT })).send({});
    expect(res.status).toBe(403);
    expect(mockDb.calls).toHaveLength(0);
  });

  test.each([['doctor', ROLE.DOCTOR], ['receptionist', ROLE.RECEPTIONIST]])('%s reaches the route', async (_, role_id) => {
    const res = await request(app)
      .post('/doctor/insert/appointment/queueNext')
      .set(authHeader({ role_id }))
      .send({});
    expect(res.status).toBe(400); // the route's own validation
  });

  test('token without role_id → 401 so the app signs in again', async () => {
    const token = jwt.sign({ uid: 1 }, process.env.JWT_SECRET_KEY);
    const res = await request(app)
      .post('/doctor/insert/appointment/queueNext')
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(res.status).toBe(401);
  });
});

describe('uploads', () => {
  test('GET /uploads/* → 401 without a token', async () => {
    const res = await request(app).get('/uploads/doctor_images/1/a.jpg');
    expect(res.status).toBe(401);
  });

  test('accepts ?token= (Image.network cannot send headers)', async () => {
    const token = authHeader().Authorization.split(' ')[1];
    const res = await request(app).get(`/uploads/does-not-exist.jpg?token=${token}`);
    expect(res.status).not.toBe(401);
  });
});

describe('public pages', () => {
  test.each(['/privacy', '/login/privacy', '/login/terms', '/login/delete-account', '/admin'])(
    'GET %s serves HTML', async (url) => {
      const res = await request(app).get(url);
      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toMatch(/html/);
    });
});

// The OTP loginTicket is signed with the same key; it must never act as a
// session (it has no role, so it slipped past every ownership check).
describe('only real access tokens authenticate', () => {
  const bearer = (payload, opts = {}) => ({
    Authorization: `Bearer ${jwt.sign(payload, process.env.JWT_SECRET_KEY, opts)}`,
  });

  test.each(PROTECTED)('%s %s → 401 with a loginTicket', async (method, url) => {
    const res = await request(app)[method](url).set(bearer({ mobile: '9123400000', purpose: 'login' }));
    expect(res.status).toBe(401);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('a token without role_id → 401', async () => {
    const res = await request(app).get('/patient/users/patientPrescriptionList/1').set(bearer({ mobile: '9123400000', uid: 1 }));
    expect(res.status).toBe(401);
  });

  test('an unsigned (alg none) token → 401', async () => {
    const none = jwt.sign({ role_id: 4, uid: 'admin' }, null, { algorithm: 'none' });
    const res = await request(app).get('/admin/doctors/pending').set('Authorization', `Bearer ${none}`);
    expect(res.status).toBe(401);
  });

  test('/uploads refuses a loginTicket in ?token=', async () => {
    const ticket = jwt.sign({ mobile: '9123400000', purpose: 'login' }, process.env.JWT_SECRET_KEY);
    const res = await request(app).get(`/uploads/doctor_images/1/x.png?token=${ticket}`);
    expect(res.status).toBe(401);
  });
});

// Verification is reviewed by an admin in the background and never restricts;
// only an admin block (active_status 1) does — for the doctor and their staff.
describe('doctor verification and block', () => {
  const staffRoutes = [
    ['post', '/doctor/insert/appointment/queueNext'],
    ['post', '/doctor/insert/walkInBook'],
    ['post', '/doctor/insert/insertPrescription'],
    ['get', '/doctor/users/patientAppointmentList/1'],
    ['get', '/doctor/users/appointment/getTodayQueue/1'],
    ['get', '/patient/users/patientPrescriptionList/10'],
    ['get', '/patient/users/fetchFamilyMembers/10'],
    ['post', '/doctor/insert/saveDoctorSchedule'],
    ['post', '/doctor/insert/insertMedicine'],
  ];

  test.each(staffRoutes)('active doctor (verified or not): %s %s is not blocked', async (method, url) => {
    const res = await request(app)[method](url).set(authHeader()).send({});
    expect(res.status).not.toBe(403);
  });

  test.each(staffRoutes)('blocked doctor: %s %s → 403 DOCTOR_BLOCKED', async (method, url) => {
    mockDb.doctorActive = false;
    const res = await request(app)[method](url).set(authHeader()).send({});
    expect(res.status).toBe(403);
    expect(res.body.code).toBe('DOCTOR_BLOCKED');
  });

  test('a receptionist of a blocked doctor is blocked too', async () => {
    mockDb.doctorActive = false;
    const res = await request(app).get('/doctor/users/appointment/getTodayQueue/1')
      .set(authHeader({ role_id: 3, uid: 5 }));
    expect(res.body.code).toBe('DOCTOR_BLOCKED');
  });

  test('patients are never affected by the doctor flag', async () => {
    mockDb.doctorActive = false;
    const res = await request(app).get('/patient/users/getNotifications/9')
      .set(authHeader({ role_id: 2, uid: 9 }));
    expect(res.status).not.toBe(403);
  });
});
