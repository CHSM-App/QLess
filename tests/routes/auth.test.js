const request = require('supertest');
const jwt = require('jsonwebtoken');
const { mockDb } = require('../helpers/db');
const { ROLE } = require('../helpers/auth');
const app = require('../../src/server');

const DEMO_MOBILE = '9876000001'; // demo range: logs in with DEMO_OTP, no SMS
const REAL_MOBILE = '9123456789';

// Which accounts the fake DB holds for the mobile under test.
function accounts({ doctor, patient, receptionist } = {}) {
  return ({ target, inputs }) => {
    if (target === 'sp_doctor_login' && inputs.operation === 'doctor_mobile_exist') return doctor ? [doctor] : [];
    if (target === 'sp_patients' && inputs.operation === 'patient_mobile_exist') return patient ? [patient] : [];
    if (target === 'sp_receptionist' && inputs.operation === 'check_phone_receptionist') return receptionist ? [receptionist] : [];
    return [];
  };
}

const sessionInserts = () => mockDb.callsTo('ManageRefreshToken', 'insert');
const decode = (token) => jwt.verify(token, process.env.JWT_SECRET_KEY);

beforeEach(() => mockDb.reset());

describe('POST /login/Createlogin — input and OTP proof', () => {
  test('400 without mobile', async () => {
    const res = await request(app).post('/login/Createlogin').send({ role: 'doctor' });
    expect(res.status).toBe(400);
  });

  test('400 without role', async () => {
    const res = await request(app).post('/login/Createlogin').send({ mobile: DEMO_MOBILE });
    expect(res.status).toBe(400);
  });

  test('401 for a demo mobile with the wrong OTP', async () => {
    const res = await request(app).post('/login/Createlogin')
      .send({ mobile: DEMO_MOBILE, role: 'doctor', otp: '000000' });
    expect(res.status).toBe(401);
    expect(sessionInserts()).toHaveLength(0);
  });

  test('401 for a real mobile without a login ticket', async () => {
    const res = await request(app).post('/login/Createlogin').send({ mobile: REAL_MOBILE, role: 'doctor' });
    expect(res.status).toBe(401);
  });

  test('401 when the login ticket was issued for another mobile', async () => {
    const loginTicket = jwt.sign({ purpose: 'login', mobile: '9999999999' }, process.env.JWT_SECRET_KEY);
    const res = await request(app).post('/login/Createlogin')
      .send({ mobile: REAL_MOBILE, role: 'doctor', loginTicket });
    expect(res.status).toBe(401);
  });

  test('a valid login ticket for the same mobile is accepted', async () => {
    mockDb.respond = accounts({ doctor: { doctor_id: 5 } });
    const loginTicket = jwt.sign({ purpose: 'login', mobile: `+91 ${REAL_MOBILE}` }, process.env.JWT_SECRET_KEY);
    const res = await request(app).post('/login/Createlogin')
      .send({ mobile: REAL_MOBILE, role: 'doctor', loginTicket });
    expect(res.status).toBe(200);
  });
});

describe('POST /login/Createlogin — role comes from the database', () => {
  const login = (role) => request(app).post('/login/Createlogin')
    .send({ mobile: DEMO_MOBILE, role, otp: '123456', deviceDetails: 'jest' });

  test('doctor: token and session carry role 1 and the doctor id', async () => {
    mockDb.respond = accounts({ doctor: { doctor_id: 5 } });
    const res = await login('doctor');

    expect(res.status).toBe(200);
    expect(res.body.roleId).toBe(ROLE.DOCTOR);
    expect(decode(res.body.accessToken)).toMatchObject({ role_id: ROLE.DOCTOR, uid: 5 });
    expect(sessionInserts()).toHaveLength(1);
    expect(sessionInserts()[0].inputs.role).toBe('doctor');
    // old sessions for the mobile are revoked first
    expect(mockDb.callsTo('ManageRefreshToken', 'revoke')).toHaveLength(1);
  });

  test('receptionist signing in via the doctor picker falls through to role 3', async () => {
    mockDb.respond = accounts({ receptionist: { recep_id: 7 } });
    const res = await login('doctor');

    expect(res.status).toBe(200);
    expect(res.body.roleId).toBe(ROLE.RECEPTIONIST);
    expect(decode(res.body.accessToken)).toMatchObject({ role_id: ROLE.RECEPTIONIST, uid: 7 });
    expect(sessionInserts()[0].inputs.role).toBe('receptionist');
  });

  // doctor_mobile_exist returns receptionist mobiles too (doctor_id NULL) —
  // the real database answers like this; it must still be a receptionist session.
  test('receptionist row from doctor_mobile_exist (doctor_id NULL) is not a doctor', async () => {
    const lookup = accounts({ receptionist: { recep_id: 7 } });
    mockDb.respond = (call) => (call.target === 'sp_doctor_login' && call.inputs.operation === 'doctor_mobile_exist'
      ? [{ doctor_id: null, mobile: DEMO_MOBILE, doc_active_status: 1, doc_is_verified: 1 }]
      : lookup(call));
    const res = await login('doctor');

    expect(res.body.roleId).toBe(ROLE.RECEPTIONIST);
    expect(decode(res.body.accessToken)).toMatchObject({ role_id: ROLE.RECEPTIONIST, uid: 7 });
  });

  test('a body claiming "doctor" cannot get a doctor session for a receptionist', async () => {
    mockDb.respond = accounts({ receptionist: { recep_id: 7 } });
    const res = await login('doctor');
    expect(decode(res.body.accessToken).role_id).not.toBe(ROLE.DOCTOR);
  });

  test('patient login never falls through to staff accounts', async () => {
    mockDb.respond = accounts({ doctor: { doctor_id: 5 }, receptionist: { recep_id: 7 } });
    const res = await login('patient');
    expect(res.status).toBe(404);
    expect(sessionInserts()).toHaveLength(0);
  });

  test('404 when the mobile holds no account', async () => {
    const res = await login('doctor');
    expect(res.status).toBe(404);
  });
});

describe('POST /login/refreshAccessToken', () => {
  const refresh = () => request(app).post('/login/refreshAccessToken').send({ refreshToken: 'old-token' });

  function storedSession(row, accountsFor = {}) {
    const lookup = accounts(accountsFor);
    return (call) => {
      if (call.target === 'ManageRefreshToken' && call.inputs.operation === 'get') return row ? [row] : [];
      return lookup(call);
    };
  }

  test('400 without a refresh token', async () => {
    const res = await request(app).post('/login/refreshAccessToken').send({});
    expect(res.status).toBe(400);
  });

  test('403 for an unknown or expired refresh token', async () => {
    const res = await refresh();
    expect(res.status).toBe(403);
  });

  // The bug fixed in migration refresh-token-role: ~15 min after login a
  // receptionist's refresh came back without a role and became a doctor.
  test('a receptionist session stays a receptionist after refresh', async () => {
    mockDb.respond = storedSession(
      { user_mobile: DEMO_MOBILE, role_id: ROLE.RECEPTIONIST, device_info: 'jest' },
      { receptionist: { recep_id: 7 } },
    );
    const res = await refresh();

    expect(res.status).toBe(200);
    expect(res.body.roleId).toBe(ROLE.RECEPTIONIST);
    expect(decode(res.body.accessToken)).toMatchObject({ role_id: ROLE.RECEPTIONIST, uid: 7 });
    expect(res.body.refreshToken).not.toBe('old-token');
    expect(sessionInserts()[0].inputs.role).toBe('receptionist');
  });

  test('falls back to the role name when role_id is not projected', async () => {
    mockDb.respond = storedSession({ user_mobile: DEMO_MOBILE, role_id: null, role: 'patient' },
      { patient: { patient_id: 3 } });
    const res = await refresh();
    expect(res.body.roleId).toBe(ROLE.PATIENT);
  });

  test('refuses (500) rather than answer with an unknown role', async () => {
    mockDb.respond = storedSession({ user_mobile: DEMO_MOBILE, role_id: null, role: null });
    const res = await refresh();

    expect(res.status).toBe(500);
    expect(res.body.roleId).toBeUndefined();
    expect(sessionInserts()).toHaveLength(0);
  });

  // A doctor an admin blocked no longer resolves (doctor_mobile_exist needs
  // active_status 0): the session ends instead of renewing without a uid.
  test('blocked doctor → 403 DOCTOR_BLOCKED, no new session', async () => {
    mockDb.respond = storedSession({ user_mobile: DEMO_MOBILE, role_id: ROLE.DOCTOR, device_info: 'jest' });
    const res = await refresh();
    expect(res.status).toBe(403);
    expect(res.body.code).toBe('DOCTOR_BLOCKED');
    expect(res.body.accessToken).toBeUndefined();
    expect(sessionInserts()).toHaveLength(0);
  });
});

// Verification runs in the background: it never filters login or the
// patients' doctor list; only an admin block (active_status) does.
describe('doctor verification SQL', () => {
  const doctorsSql = require('../../src/queries/doctors');
  const patientsSql = require('../../src/queries/patients');

  test('a new doctor is saved as pending review (is_verified 1)', () => {
    expect(doctorsSql.ops.Insert).toMatch(/@clinic_id,\s*0, 1, @gender_id, @image\)/);
  });

  test('login lookup ignores verification, still refuses blocked doctors', () => {
    expect(doctorsSql.ops.check_phone_doctor).not.toMatch(/is_verified/);
    expect(doctorsSql.ops.check_phone_doctor).toMatch(/doc_active_status = 0/);
  });

  test("patients' doctor list hides blocked doctors, not unverified ones", () => {
    const text = Object.values(patientsSql.ops).find((t) => /ACTIVE DOCTORS/.test(t));
    expect(text).toMatch(/dl_main\.active_status = 0/);
    expect(text).not.toMatch(/dl_main\.is_verified/);
  });
});
