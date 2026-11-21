const request = require('supertest');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

// S1: this profile includes the doctor's mobile, email, licence no. and FCM
// token — it must not be readable without a clinic-staff token.
const URL = '/login/getDoctorProfileByClinic?clinic_id=CL001&doctor_id=1';
const ROW = { doctor_id: 1, name: 'Dr A', mobile: '9876000001', email: 'a@x.in', license_no: 'L1', token: 'fcm', clinic_id: 'CL001' };

beforeEach(() => {
  mockDb.reset();
  mockDb.respond = ({ target }) => (/doctor_login_vw/.test(target) ? [ROW] : []);
});

test('401 without a token, nothing read', async () => {
  const res = await request(app).get(URL);
  expect(res.status).toBe(401);
  expect(mockDb.calls).toHaveLength(0);
});

test('403 for a patient token', async () => {
  const res = await request(app).get(URL).set(authHeader({ role_id: ROLE.PATIENT }));
  expect(res.status).toBe(403);
  expect(mockDb.calls).toHaveLength(0);
});

test.each([['receptionist', ROLE.RECEPTIONIST], ['doctor', ROLE.DOCTOR]])('%s gets the full profile (app unchanged)', async (_, role_id) => {
  const res = await request(app).get(URL).set(authHeader({ role_id }));
  expect(res.status).toBe(200);
  expect(res.body).toEqual([ROW]);
  expect(mockDb.calls[0].inputs).toMatchObject({ doctor_id: 1, clinic_id: 'CL001' });
});

test('no clinic_id / doctor_id → []', async () => {
  const res = await request(app).get('/login/getDoctorProfileByClinic').set(authHeader({ role_id: ROLE.RECEPTIONIST }));
  expect(res.body).toEqual([]);
});
