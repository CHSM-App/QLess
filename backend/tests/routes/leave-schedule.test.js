const request = require('supertest');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const fcm = require('../../src/fcm');
const app = require('../../src/server');

const doctor = () => authHeader({ role_id: ROLE.DOCTOR, uid: 1 });
const post = (url, body) => request(app).post('/doctor/insert' + url).set(doctor()).send(body);
const ops = (proc) => mockDb.calls.filter((c) => c.target === proc).map((c) => c.inputs.operation);

beforeEach(() => { mockDb.reset(); fcm.messaging().send.mockClear(); });

describe('POST /addDoctorLeave', () => {
  const leave = { doctor_id: 1, from_date: '2026-12-01', to_date: '2026-12-02', reason: 'Conference', clinic_id: 'CL001' };
  const db = ({ affected = 0, add = [{ leave_id: 5 }], context = [] } = {}) => ({ target, inputs }) => {
    if (inputs.operation === 'COUNT_AFFECTED') return [{ cnt: affected }];
    if (inputs.operation === 'ADD_LEAVE') return add;
    if (target === 'sp_notification' && inputs.operation === 'APPT_CONTEXT_DOCTOR_RANGE') return context;
    return [];
  };

  test('400 without doctor_id / dates, or from > to — no DB call', async () => {
    expect((await post('/addDoctorLeave', { ...leave, to_date: undefined })).status).toBe(400);
    expect((await post('/addDoctorLeave', { ...leave, from_date: '2026-12-05' })).status).toBe(400);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('bookings in range and no force → 409 with the count, nothing written', async () => {
    mockDb.respond = db({ affected: 3 });
    const res = await post('/addDoctorLeave', leave);
    expect(res.status).toBe(409);
    expect(res.body.affected_appointments).toBe(3);
    expect(ops('sp_doctor_leave')).toEqual(['COUNT_AFFECTED']);
  });

  test('force → leave added, bookings cancelled, each patient notified', async () => {
    mockDb.respond = db({ affected: 2, context: [
      { owner_id: 4, owner_token: 'fcm-4', doctor_name: 'Asha', appointment_date: '2026-12-01', start_time: '10:00', appointment_id: 70 },
      { owner_id: 5, owner_token: 'fcm-5', doctor_name: 'Asha', appointment_date: '2026-12-02', start_time: null, appointment_id: 71 },
    ] });
    const res = await post('/addDoctorLeave', { ...leave, force: true });

    expect(res.body).toMatchObject({ success: true, cancelled_appointments: 2 });
    expect(ops('sp_doctor_leave')).toEqual(['COUNT_AFFECTED', 'ADD_LEAVE', 'APPLY_LEAVE_CANCEL']);
    expect(fcm.messaging().send).toHaveBeenCalledTimes(2);
    expect(mockDb.callsTo('sp_notification', 'INSERT')).toHaveLength(2);
  });

  test.each([['PAST_DATE', 'Leave start date is in the past'], ['BAD_RANGE', 'Invalid leave date range']])(
    'database refuses (%s) → 400', async (error, message) => {
      mockDb.respond = db({ add: [{ error }] });
      const res = await post('/addDoctorLeave', leave);
      expect(res.status).toBe(400);
      expect(res.body.message).toBe(message);
    });
});

describe('leave list / cancel', () => {
  test('GET /doctorLeaves/:doctor_id/:clinic_id', async () => {
    mockDb.respond = () => [{ leave_id: 5, from_date: '2026-12-01' }];
    const res = await request(app).get('/doctor/insert/doctorLeaves/1/CL001').set(doctor());
    expect(res.status).toBe(200);
    expect(mockDb.callsTo('sp_doctor_leave', 'LIST_LEAVE')[0].inputs).toMatchObject({ doctor_id: '1', clinic_id: 'CL001' });
  });

  test('POST /cancelDoctorLeave passes the leave id', async () => {
    mockDb.respond = () => [{ success: 1 }];
    await post('/cancelDoctorLeave', { doctor_id: 1, leave_id: 5, clinic_id: 'CL001' });
    expect(mockDb.callsTo('sp_doctor_leave', 'CANCEL_LEAVE')[0].inputs).toMatchObject({ doctor_id: 1, leave_id: 5 });
  });
});

describe('schedule', () => {
  test('saveDoctorSchedule: 400 without a schedule array', async () => {
    expect((await post('/saveDoctorSchedule', { doctor_id: 1 })).status).toBe(400);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('saveDoctorSchedule: overlapping slots → 400 before any write', async () => {
    mockDb.respond = () => [];
    const res = await post('/saveDoctorSchedule', { doctor_id: 1, clinic_id: 'CL001', schedule: [{ day: 'Monday', is_enabled: 1, slots: [
      { start_time: '09:00', end_time: '12:00', booking_mode: 1 }, { start_time: '11:00', end_time: '13:00', booking_mode: 2, slot_duration: 15 }] }] });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/overlap/);
    expect(ops('sp_doctor_schedule').filter((o) => /UPSERT|DELETE/.test(o))).toHaveLength(0);
  });

  test('saveDoctorSchedule: new day + slot → UPSERT_DAY then UPSERT_SLOT', async () => {
    mockDb.respond = ({ target, inputs }) => {
      if (target !== 'sp_doctor_schedule') return [];
      if (inputs.operation === 'UPSERT_DAY') return [{ availability_id: 9 }];
      if (inputs.operation === 'UPSERT_SLOT') return [{ slot_id: 30 }];
      return [];
    };
    const res = await post('/saveDoctorSchedule', { doctor_id: 1, clinic_id: 'CL001', schedule: [{ day: 'Monday', is_enabled: 1,
      slots: [{ start_time: '09:00', end_time: '12:00', booking_mode: 1, slot_duration: 10, max_queue_length: 20 }] }] });
    expect(res.status).toBe(200);
    expect(mockDb.callsTo('sp_doctor_schedule', 'UPSERT_DAY')[0].inputs).toMatchObject({ doctor_id: 1, day_of_week: 'Monday', is_enabled: 1 });
    expect(mockDb.callsTo('sp_doctor_schedule', 'UPSERT_SLOT')[0].inputs).toMatchObject({ availability_id: 9, start_time: '09:00', end_time: '12:00' });
  });

  test('GET /doctor/users/getDoctorSchedule/:doctor_id', async () => {
    mockDb.respond = () => [];
    const res = await request(app).get('/doctor/users/getDoctorSchedule/1?clinic_id=CL001').set(doctor());
    expect(res.status).toBe(200);
    expect(mockDb.callsTo('sp_doctor_schedule', 'GET')).toHaveLength(1);
  });

  test('POST /addQueueStartTime', async () => {
    mockDb.respond = () => [{ success: 1 }];
    await post('/addQueueStartTime/', { doctor_id: 1, q_start_before: 20 });
    expect(mockDb.callsTo('sp_doctor_login', 'Insert_Q_StartTime')[0].inputs).toMatchObject({ doctor_id: 1, q_start_before: 20 });
  });
});
