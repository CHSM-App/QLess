const request = require('supertest');
const jwt = require('jsonwebtoken');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

// S3: a patient token (uid 9) may only touch patient 9's records — or, where
// the app books/reviews for family, one of patient 9's family members.
const me = () => authHeader({ role_id: ROLE.PATIENT, uid: 9 });
const doctor = () => authHeader({ role_id: ROLE.DOCTOR, uid: 1 });
const blocked = (res) => expect(res.status).toBe(403);
const allowed = (res) => expect([401, 403]).not.toContain(res.status);

beforeEach(() => mockDb.reset());

describe('ids in the URL', () => {
  test.each([
    ['get', '/patient/users/favoriteDoctors/10'],
    ['get', '/patient/users/getNotifications/10'],
    ['get', '/patient/users/patientPrescriptionList/10'],
    ['get', '/patient/users/getDoctors/10'],
    ['get', '/patient/users/fetchFamilyMembers/10'],
    ['get', '/patient/insert/getPatientAppointments/10'],
    ['post', '/patient/users/markAllNotificationsRead/10'],
    ['delete', '/patient/index/favoriteDoctor/10/2/CL1'],
  ])("%s %s → 403 (another patient's id)", async (method, url) => {
    const res = await request(app)[method](url).set(me());
    blocked(res);
    expect(mockDb.calls).toHaveLength(0);
  });

  test.each([
    ['get', '/patient/users/favoriteDoctors/9'],
    ['get', '/patient/users/getNotifications/9'],
    ['get', '/patient/users/fetchFamilyMembers/9'],
  ])('%s %s → own id passes', async (method, url) => {
    allowed(await request(app)[method](url).set(me()));
  });

  test('member, appointment and prescription ids are looked up', async () => {
    mockDb.owns = false;
    blocked(await request(app).delete('/patient/index/deleteFamilyMember/41').set(me()));
    blocked(await request(app).get('/patient/users/review/appointment/77').set(me()));
    blocked(await request(app).get('/patient/users/patientPrescriptionDetails/5').set(me()));
    mockDb.owns = true;
    allowed(await request(app).get('/patient/users/patientPrescriptionDetails/5').set(me()));
  });

  test('delete review: family member id allowed when the appointment is ours', async () => {
    allowed(await request(app).delete('/patient/index/review/77/41').set(me()));
    mockDb.owns = false;
    blocked(await request(app).delete('/patient/index/review/77/41').set(me()));
  });
});

describe('ids in the body', () => {
  const book = (body) => request(app).post('/patient/insert/appointment/book').set(me())
    .send({ doctor_id: 2, appointment_date: '2026-11-20', slot_id: 3, ...body });

  test('book for myself → passes; for another patient → 403', async () => {
    allowed(await book({ patient_id: 9, user_type: 1 }));
    blocked(await book({ patient_id: 10, user_type: 1 }));
  });

  test('book for my family member (user_type 2) → passes; not my member → 403', async () => {
    allowed(await book({ patient_id: 41, user_type: 2 }));
    mockDb.owns = false;
    blocked(await book({ patient_id: 41, user_type: 2 }));
  });

  test('a member id with user_type 1 would book as that patient → 403', async () => {
    blocked(await book({ patient_id: 41, user_type: 1 }));
  });

  test('review written in my name only', async () => {
    const res = await request(app).post('/patient/insert/review/add').set(me())
      .send({ appointment_id: 77, doctor_id: 2, patient_id: 9, rating: 4, reviewed_by_user_id: 10 });
    blocked(res);
  });

  test('family member saved under my family only', async () => {
    blocked(await request(app).post('/patient/insert/insertFamilyMember').set(me()).send({ family_id: 10, name: 'X' }));
    allowed(await request(app).post('/patient/insert/insertFamilyMember').set(me()).send({ family_id: 9, name: 'X' }));
  });

  test("someone else's appointment / notification → 403", async () => {
    mockDb.owns = false;
    blocked(await request(app).post('/patient/insert/appointment/cancel').set(me()).send({ appointment_id: 77 }));
    blocked(await request(app).post('/patient/insert/rescheduleAppointment').set(me()).send({ appointment_id: 77, doctor_id: 2 }));
    blocked(await request(app).post('/patient/users/markNotificationRead').set(me()).send({ notification_id: 3, patient_id: 9 }));
  });
});

describe('who is checked', () => {
  test('staff are kept to the few patient routes the clinic app uses', async () => {
    blocked(await request(app).get('/patient/users/getNotifications/10').set(doctor()));
    blocked(await request(app).get('/patient/users/favoriteDoctors/10').set(doctor()));
    blocked(await request(app).post('/patient/insert/appointment/book').set(doctor()).send({}));
    blocked(await request(app).delete('/patient/index/deleteFamilyMember/5').set(doctor()));
    blocked(await request(app).get('/patient/users/getNotifications/10').set(authHeader({ role_id: ROLE.ADMIN, uid: 'admin' })));
    allowed(await request(app).get('/patient/users/fetchFamilyMembers/10').set(doctor()));
    allowed(await request(app).get('/patient/users/getDoctorAvailability/1/CL1').set(doctor()));
  });

  test("staff need the patient to have seen their doctor, and the prescription to be their doctor's", async () => {
    mockDb.owns = false;
    blocked(await request(app).get('/patient/users/patientPrescriptionList/10').set(doctor()));
    // (owns = false also hides a receptionist's own record → 401, so a doctor token here)
    blocked(await request(app).get('/patient/users/patientPrescriptionDetails/77').set(doctor()));
  });

  test("staff prescription history is filtered to their own doctor's prescriptions", async () => {
    mockDb.staffDoctorId = 4;
    allowed(await request(app).get('/patient/users/patientPrescriptionList/10').set(authHeader({ role_id: ROLE.RECEPTIONIST, uid: 3 })));
    expect(mockDb.callsTo('sp_prescription', 'PatientPrescriptionList')[0].inputs.doctor_id).toBe(4);
    mockDb.reset();
    allowed(await request(app).get('/patient/users/patientPrescriptionList/9').set(me()));
    expect(mockDb.callsTo('sp_prescription', 'PatientPrescriptionList')[0].inputs.doctor_id).toBeUndefined();
  });

  test('a patient token without uid → 401 so the app refreshes it', async () => {
    const token = jwt.sign({ role_id: ROLE.PATIENT }, process.env.JWT_SECRET_KEY);
    const res = await request(app).get('/patient/users/favoriteDoctors/9').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(401);
  });

  test('routes without patient ids (doctor lists, availability) are unaffected', async () => {
    mockDb.owns = false;
    allowed(await request(app).get('/patient/users/getDoctorAvailability/2/CL1').set(me()));
    allowed(await request(app).get('/patient/users/review/doctor/2/CL1').set(me()));
  });
});
