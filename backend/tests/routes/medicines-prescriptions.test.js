const request = require('supertest');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const fcm = require('../../src/fcm');
const app = require('../../src/server');

const doctor = () => authHeader({ role_id: ROLE.DOCTOR, uid: 1 });

beforeEach(() => { mockDb.reset(); fcm.messaging().send.mockClear(); });

describe('medicines', () => {
  const add = (body) => request(app).post('/doctor/insert/insertMedicine').set(doctor()).send(body);
  const med = { doctor_id: 1, medicine_name: 'Paracetamol', medicine_type_id: 1, brand_name: 'Crocin', strength: '500mg', components: 'Paracetamol 500mg' };

  test('insert passes name, type, brand, strength, components', async () => {
    mockDb.respond = () => [{ Message: 'Medicine added successfully.' }];
    const res = await add(med);
    expect(res.status).toBe(200);
    expect(mockDb.callsTo('sp_Medicine_Master', 'Insert')[0].inputs).toMatchObject(med);
  });

  // B14: the check looked for "already exists"; the database says
  // "Medicine already in your list." and the duplicate answered 200.
  test('duplicate → 409 (B14)', async () => {
    mockDb.respond = () => [{ Message: 'Medicine already in your list.' }];
    const res = await add(med);
    expect(res.status).toBe(409);
    expect(res.body.success).toBe(0);
  });

  test('list, types, suggestions', async () => {
    mockDb.respond = () => [{ medicine_id: 1 }];
    expect((await request(app).get('/doctor/users/getAllMedicines/1').set(doctor())).status).toBe(200);
    expect((await request(app).get('/doctor/users/getMedicineTypes').set(doctor())).status).toBe(200);
    expect((await request(app).get('/doctor/users/getMedicineSuggestions?q=Cro').set(doctor())).status).toBe(200);
    expect(mockDb.callsTo('sp_Medicine_Master', 'getSuggestions')[0].inputs.search_query).toBe('Cro');
    expect(mockDb.callsTo('sp_Medicine_Master', 'fetchAllMedicines')[0].inputs.doctor_id).toBe('1');
  });

  test('delete is doctor-only and passes both ids', async () => {
    mockDb.respond = () => [{ Message: 'Medicine removed from your list.' }];
    expect((await request(app).delete('/doctor/index/deleteMedicine/1/7').set(authHeader({ role_id: ROLE.RECEPTIONIST }))).status).toBe(403);
    await request(app).delete('/doctor/index/deleteMedicine/1/7').set(doctor());
    expect(mockDb.callsTo('sp_Medicine_Master', 'Delete')[0].inputs).toMatchObject({ doctor_id: 1, medicine_id: 7 });
  });
});

describe('POST /doctor/insert/insertPrescription', () => {
  const rx = { patient_id: 4, doctor_id: 1, prescription_date: '2026-11-20', symptoms: 's', diagnosis: 'd', user_type: 1, appointment_id: 50,
    clinical_notes: 'n', follow_up_date: '2026-11-27', advice: 'a', clinic_id: 'CL001' };
  const save = (body) => request(app).post('/doctor/insert/insertPrescription').set(doctor()).send(body);
  const db = ({ existing = null } = {}) => ({ kind, target, inputs }) => {
    if (kind === 'query' && /FROM patient_records WHERE appointment_id/.test(target)) return existing ? [{ prescription_id: existing }] : [];
    if (target === 'sp_prescription') return [{ success: 1, prescription_id: 90 }];
    if (kind === 'query' && /FROM patients WHERE token/.test(target)) return [];
    return [];
  };

  test.each([['patient_id'], ['doctor_id']])('400 without %s', async (f) => {
    expect((await save({ ...rx, [f]: undefined })).status).toBe(400);
  });

  test('one Insert per medicine; the first creates the prescription, the rest reuse its id', async () => {
    mockDb.respond = db();
    const res = await save({ ...rx, medicines: [
      { medicine_id: 1, medicine_type_id: 1, frequency: '1-0-1', duration: '5 days', tablet_dosage: '1' },
      { medicine_id: 2, medicine_type_id: 2, frequency: '0-0-1', duration: '3 days', syrup_dosage_ml: '5' },
    ] });
    expect(res.status).toBe(200);
    const inserts = mockDb.callsTo('sp_prescription', 'Insert');
    expect(inserts).toHaveLength(2);
    expect(inserts[0].inputs).toMatchObject({ prescription_id: 0, medicine_id: 1, tablet_dosage: '1', appointment_id: 50 });
    expect(inserts[1].inputs).toMatchObject({ prescription_id: 90, medicine_id: 2, syrup_dosage_ml: '5' });
  });

  test('a replayed save for the same appointment returns the existing prescription', async () => {
    mockDb.respond = db({ existing: 77 });
    const res = await save({ ...rx, offline_queued_at: new Date().toISOString(), medicines: [] });
    expect(res.body).toEqual({ success: true, prescription_id: 77, message: 'Prescription already saved' });
    expect(mockDb.callsTo('sp_prescription')).toHaveLength(0);
  });

  test('database refusal → 500, no notification', async () => {
    mockDb.respond = ({ target }) => (target === 'sp_prescription' ? [{ success: 0, message: 'nope' }] : []);
    const res = await save({ ...rx, medicines: [] });
    expect(res.status).toBe(500);
    expect(mockDb.callsTo('sp_notification', 'INSERT')).toHaveLength(0);
  });
});

describe('prescription reads', () => {
  test('doctor: appointment-wise; patient: list and detail', async () => {
    mockDb.respond = () => [{ prescription_id: 1 }];
    expect((await request(app).get('/doctor/users/appointmentWisePrescription/50').set(doctor())).status).toBe(200);
    const patient = authHeader({ role_id: ROLE.PATIENT, uid: 4 });
    expect((await request(app).get('/patient/users/patientPrescriptionList/4').set(patient)).body).toEqual([{ prescription_id: 1 }]);
    expect((await request(app).get('/patient/users/patientPrescriptionDetails/1').set(patient)).status).toBe(200);
    expect(mockDb.callsTo('sp_prescription').map((c) => c.inputs.operation))
      .toEqual(['AppointmentWisePrescription', 'PatientPrescriptionList', 'PrescriptionDetail']);
  });
});
