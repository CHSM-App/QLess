const request = require('supertest');
const jwt = require('jsonwebtoken');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

beforeEach(() => mockDb.reset());

// S11: updating a profile (and its mobile number) needs that user's own token.
describe('profile updates are owner-only', () => {
  const patientUpdate = (headers) => request(app).post('/login/patient').set(headers || {})
    .field('patient_id', '4').field('name', 'Hijacked').field('mobile_no', '9000000000');
  const doctorUpdate = (headers) => request(app).post('/login/doctor').set(headers || {})
    .field('doctor_id', '1').field('name', 'Hijacked').field('mobile', '9000000000');

  test('patient update without a token → 401, nothing written', async () => {
    const res = await patientUpdate();
    expect(res.status).toBe(401);
    expect(mockDb.callsTo('sp_patients')).toHaveLength(0);
  });

  test("patient update with another patient's token → 403", async () => {
    expect((await patientUpdate(authHeader({ role_id: ROLE.PATIENT, uid: 5 }))).status).toBe(403);
    expect(mockDb.callsTo('sp_patients')).toHaveLength(0);
  });

  test('patient update with a doctor token → 403', async () => {
    expect((await patientUpdate(authHeader({ role_id: ROLE.DOCTOR, uid: 4 }))).status).toBe(403);
  });

  test('patient updating their own profile goes through', async () => {
    mockDb.respond = ({ target }) => (target === 'sp_patients' ? [{ patient_id: 4 }] : []);
    const res = await patientUpdate(authHeader({ role_id: ROLE.PATIENT, uid: 4 }));
    expect(res.status).toBe(200);
    expect(mockDb.callsTo('sp_patients', 'Update')[0].inputs).toMatchObject({ patient_id: '4' });
  });

  test('patient registration (no patient_id) stays open', async () => {
    mockDb.respond = ({ target }) => (target === 'sp_patients' ? [{ patient_id: 77 }] : []);
    const res = await request(app).post('/login/patient').field('name', 'New').field('mobile_no', '9000000001');
    expect(res.status).toBe(200);
  });

  test('doctor update: no token 401, other doctor 403', async () => {
    expect((await doctorUpdate()).status).toBe(401);
    expect((await doctorUpdate(authHeader({ role_id: ROLE.DOCTOR, uid: 2 }))).status).toBe(403);
    expect(mockDb.callsTo('sp_doctor_login')).toHaveLength(0);
  });

  test('a doctor token without uid can no longer update any doctor', async () => {
    const noUid = jwt.sign({ role_id: ROLE.DOCTOR, mobile: '9876000001' }, process.env.JWT_SECRET_KEY);
    const res = await doctorUpdate({ Authorization: `Bearer ${noUid}` });
    expect(res.status).toBe(403);
    expect(mockDb.callsTo('sp_doctor_login')).toHaveLength(0);
  });
});

// S14: registration needs OTP proof; the server never mints an unproven ticket.
describe('registration proof of OTP', () => {
  const ticketFor = (mobile) => jwt.sign({ mobile, purpose: 'login' }, process.env.JWT_SECRET_KEY, { expiresIn: '5m' });
  const registerDoctor = (fields) => {
    let r = request(app).post('/login/doctor');
    for (const [k, v] of Object.entries({ name: 'Dr New', mobile: '9123400000', clinic_name: 'C', ...fields })) r = r.field(k, v);
    return r;
  };
  beforeEach(() => {
    mockDb.respond = ({ target }) => (target === 'sp_doctor_login' ? [{ doctor_id: 9, clinic_id: 'CL009' }] : []);
  });
  afterEach(() => { delete process.env.SIGNUP_REQUIRES_OTP; });

  test('no proof, flag off → allowed (logged), but NO login ticket handed out', async () => {
    const res = await registerDoctor();
    expect(res.status).toBe(200);
    expect(res.body.loginTicket).toBeUndefined();
  });

  test('valid ticket for this mobile → allowed, ticket echoed for the auto sign-in', async () => {
    const t = ticketFor('9123400000');
    const res = await registerDoctor({ loginTicket: t });
    expect(res.body.loginTicket).toBe(t);
  });

  test("a ticket for another number is not echoed", async () => {
    const res = await registerDoctor({ loginTicket: ticketFor('9999999999') });
    expect(res.body.loginTicket).toBeUndefined();
  });

  test('SIGNUP_REQUIRES_OTP=true → no proof is refused before anything is written', async () => {
    process.env.SIGNUP_REQUIRES_OTP = 'true';
    expect((await registerDoctor()).status).toBe(401);
    expect((await request(app).post('/login/patient').field('name', 'P').field('mobile_no', '9123400001')).status).toBe(401);
    expect(mockDb.calls).toHaveLength(0);
    expect((await registerDoctor({ loginTicket: ticketFor('9123400000') })).status).toBe(200);
  });
});

// S15: demo numbers are ordinary numbers unless DEMO_ENABLED=true.
describe('demo logins', () => {
  afterEach(() => { process.env.DEMO_ENABLED = 'true'; });

  test('demo disabled → the demo OTP no longer logs anyone in', async () => {
    process.env.DEMO_ENABLED = 'false';
    mockDb.respond = ({ inputs }) => (inputs.operation === 'doctor_mobile_exist' ? [{ doctor_id: 1 }] : []);
    const res = await request(app).post('/login/Createlogin').send({ mobile: '9876000001', role: 'doctor', otp: '123456' });
    expect(res.status).toBe(401);
    expect(res.body.error).toBe('OTP verification required');
  });

  test('demo enabled → demo number + demo OTP works', async () => {
    mockDb.respond = ({ inputs }) => (inputs.operation === 'doctor_mobile_exist' ? [{ doctor_id: 1 }] : []);
    const res = await request(app).post('/login/Createlogin').send({ mobile: '9876000001', role: 'doctor', otp: '123456' });
    expect(res.status).toBe(200);
  });
});

// S12: the push token is saved for the signed-in account only.
describe('POST /login/saveFirebaseToken', () => {
  const save = (headers, body) => request(app).post('/login/saveFirebaseToken').set(headers || {}).send(body);

  test('401 without a token, nothing written', async () => {
    const res = await save(null, { firebaseToken: 'x', mobile: '9876000001', role: 'doctor' });
    expect(res.status).toBe(401);
    expect(mockDb.calls).toHaveLength(0);
  });

  test("mobile and role come from the token — a body naming someone else's mobile is ignored", async () => {
    mockDb.respond = () => [{ success: 1 }];
    const res = await save(authHeader({ role_id: ROLE.PATIENT, uid: 4, mobile: '9878000001' }),
      { firebaseToken: 'my-device', mobile: '9876000001', role: 'doctor' });
    expect(res.status).toBe(200);
    expect(mockDb.callsTo('sp_doctor_login', 'saveFirebaseToken')[0].inputs)
      .toEqual({ operation: 'saveFirebaseToken', mobile: '9878000001', token: 'my-device', role: 'patient' });
  });

  test('400 without firebaseToken; admin token cannot register one', async () => {
    expect((await save(authHeader({ role_id: ROLE.DOCTOR, mobile: '9876000001' }), {})).status).toBe(400);
    expect((await save(authHeader({ role_id: ROLE.ADMIN, mobile: 'x' }), { firebaseToken: 'x' })).status).toBe(403);
  });
});

// B16: an Update that changes the mobile number needs OTP proof for the new
// number (the app's change-mobile OTP was never real).
describe('mobile change proof of OTP', () => {
  const ticketFor = (mobile) => jwt.sign({ mobile, purpose: 'login' }, process.env.JWT_SECRET_KEY, { expiresIn: '5m' });
  // authHeader's token mobile is 9876543210.
  const patientUpdate = (mobile, extra = {}) => {
    let r = request(app).post('/login/patient').set(authHeader({ role_id: ROLE.PATIENT, uid: 4 }))
      .field('patient_id', '4').field('name', 'Me').field('mobile_no', mobile);
    for (const [k, v] of Object.entries(extra)) r = r.field(k, v);
    return r;
  };
  const doctorUpdate = (mobile) => request(app).post('/login/doctor').set(authHeader({ role_id: ROLE.DOCTOR, uid: 1 }))
    .field('doctor_id', '1').field('name', 'Dr').field('mobile', mobile);
  beforeEach(() => {
    mockDb.respond = ({ target }) => (target === 'sp_patients' ? [{ patient_id: 4 }]
      : target === 'sp_doctor_login' ? [{ doctor_id: 1, clinic_id: 'CL001' }] : []);
  });
  afterEach(() => { delete process.env.MOBILE_CHANGE_REQUIRES_OTP; });

  test('flag off → a new number without proof is allowed (logged)', async () => {
    expect((await patientUpdate('9000000000')).status).toBe(200);
  });

  test('flag on → a new number without proof is refused, nothing written', async () => {
    process.env.MOBILE_CHANGE_REQUIRES_OTP = 'true';
    expect((await patientUpdate('9000000000')).status).toBe(401);
    expect((await doctorUpdate('9000000000')).status).toBe(401);
    expect(mockDb.callsTo('sp_patients')).toHaveLength(0);
    expect(mockDb.callsTo('sp_doctor_login')).toHaveLength(0);
  });

  test('flag on → a ticket for the new number lets it through', async () => {
    process.env.MOBILE_CHANGE_REQUIRES_OTP = 'true';
    expect((await patientUpdate('9000000000', { loginTicket: ticketFor('9000000000') })).status).toBe(200);
  });

  test('flag on → keeping the signed-in number needs no proof', async () => {
    process.env.MOBILE_CHANGE_REQUIRES_OTP = 'true';
    expect((await patientUpdate('+91 98765 43210')).status).toBe(200);
  });
});
