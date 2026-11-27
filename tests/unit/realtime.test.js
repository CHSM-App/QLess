// Socket doctor presence events (security review #4): only the doctor's own
// staff may mark a doctor online/offline.
const jwt = require('jsonwebtoken');
const { mockDb } = require('../helpers/db');
const { makeToken, ROLE } = require('../helpers/auth');
const { resolveDoctorEvent } = require('../../src/realtime');

beforeEach(() => {
  mockDb.reset();
  delete process.env.SOCKET_LEGACY_DOCTOR_EVENTS;
});

test("the doctor's own token is accepted", async () => {
  expect(await resolveDoctorEvent({ doctorId: 7, token: makeToken({ uid: 7 }) })).toBe(7);
});

test("a receptionist acting for that doctor is accepted", async () => {
  mockDb.staffDoctorId = 7;
  expect(await resolveDoctorEvent({ doctorId: 7, token: makeToken({ role_id: ROLE.RECEPTIONIST, uid: 3 }) })).toBe(7);
});

test("another doctor's id is refused", async () => {
  expect(await resolveDoctorEvent({ doctorId: 8, token: makeToken({ uid: 7 }) })).toBeNull();
});

test('patient tokens, login tickets and junk are refused', async () => {
  expect(await resolveDoctorEvent({ doctorId: 9, token: makeToken({ role_id: ROLE.PATIENT, uid: 9 }) })).toBeNull();
  const ticket = jwt.sign({ mobile: '9123400000', purpose: 'login' }, process.env.JWT_SECRET_KEY);
  expect(await resolveDoctorEvent({ doctorId: 9, token: ticket })).toBeNull();
  expect(await resolveDoctorEvent({ doctorId: 'x', token: makeToken() })).toBeNull();
  expect(await resolveDoctorEvent({ doctorId: 1 })).toBeNull();
});

test('a bare id is accepted only while the legacy flag is on', async () => {
  expect(await resolveDoctorEvent(7)).toBeNull();
  process.env.SOCKET_LEGACY_DOCTOR_EVENTS = 'true';
  expect(await resolveDoctorEvent(7)).toBe(7);
  expect(await resolveDoctorEvent('abc')).toBeNull();
});
