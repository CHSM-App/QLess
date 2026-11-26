const request = require('supertest');
const bcrypt = require('bcryptjs');
const axios = require('axios');
const jwt = require('jsonwebtoken');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

jest.mock('axios');

const patient = () => authHeader({ role_id: ROLE.PATIENT, uid: 4 });

beforeEach(() => {
  mockDb.reset();
  axios.post.mockReset();
  axios.post.mockResolvedValue({ data: { IsSuccess: true } });
  process.env.WHATSAPP_API_TOKEN = 'test-token';
});
afterAll(() => { process.env.WHATSAPP_API_TOKEN = ''; });

describe('patient inbox', () => {
  test('list, mark one, mark all', async () => {
    mockDb.respond = ({ inputs }) => (inputs.operation === 'LIST' ? [{ notification_id: 1, title: 'T' }] : [{ success: 1 }]);
    expect((await request(app).get('/patient/users/getNotifications/4').set(patient())).status).toBe(200);
    await request(app).post('/patient/users/markNotificationRead').set(patient()).send({ notification_id: 1, patient_id: 4 });
    await request(app).post('/patient/users/markAllNotificationsRead/4').set(patient());
    expect(mockDb.callsTo('sp_notification').map((c) => c.inputs.operation)).toEqual(['LIST', 'MARK_READ', 'MARK_ALL_READ']);
    expect(mockDb.callsTo('sp_notification', 'MARK_READ')[0].inputs).toMatchObject({ notification_id: 1, patient_id: 4 });
  });

  test('doctor-side insertNotification stores a row', async () => {
    mockDb.respond = () => [{ success: 1 }];
    await request(app).post('/doctor/insert/insertNotification').set(authHeader({ role_id: ROLE.DOCTOR }))
      .send({ patient_id: 4, title: 'T', body: 'B', type: 'general', ref_id: 9 });
    expect(mockDb.callsTo('sp_notification', 'INSERT')[0].inputs).toMatchObject({ patient_id: 4, title: 'T', type: 'general', ref_id: '9' });
  });
});

describe('login OTP', () => {
  const MOBILE = '9123456789';
  const OTP = '246810';

  test('send-otp: bad number → 400, nothing sent', async () => {
    expect((await request(app).post('/login/send-otp').send({ mobile_no: '12345' })).status).toBe(400);
    expect(axios.post).not.toHaveBeenCalled();
  });

  test('send-otp: WhatsApp gets the code, the database only its hash, the response neither', async () => {
    mockDb.respond = () => [{ status: 1 }];
    const res = await request(app).post('/login/send-otp').send({ mobile_no: '+91 ' + MOBILE });
    expect(res.status).toBe(200);
    const code = axios.post.mock.calls[0][1].OtpCode;
    const stored = mockDb.callsTo('sp_otp', 'send_otp')[0].inputs;
    expect(stored.mobile_no).toBe(MOBILE);
    expect(bcrypt.compareSync(code, stored.otp_hash)).toBe(true);
    expect(JSON.stringify(res.body)).not.toContain(code);
  });

  describe('OTP_TO_CONSOLE (WhatsApp down)', () => {
    let print;
    beforeEach(() => { process.env.OTP_TO_CONSOLE = '1'; print = jest.spyOn(console, 'log').mockImplementation(() => {}); });
    afterEach(() => { process.env.OTP_TO_CONSOLE = ''; process.env.NODE_ENV = 'test'; print.mockRestore(); });

    test('prints the code instead of sending it', async () => {
      mockDb.respond = () => [{ status: 1 }];
      const res = await request(app).post('/login/send-otp').send({ mobile_no: MOBILE });
      expect(res.status).toBe(200);
      expect(axios.post).not.toHaveBeenCalled();
      const code = print.mock.calls.flat().join(' ').match(/→ (\d{6})/)[1];
      expect(bcrypt.compareSync(code, mockDb.callsTo('sp_otp', 'send_otp')[0].inputs.otp_hash)).toBe(true);
    });

    test('ignored in production', async () => {
      process.env.NODE_ENV = 'production';
      mockDb.respond = () => [{ status: 1 }];
      await request(app).post('/login/send-otp').send({ mobile_no: MOBILE });
      expect(print).not.toHaveBeenCalledWith(expect.stringContaining('[OTP]'));
    });
  });

  test('verify-otp: right code → login ticket for that mobile, marked verified', async () => {
    mockDb.respond = ({ inputs }) => (inputs.operation === 'verify_otp' ? [{ status: 1, otp_hash: bcrypt.hashSync(OTP, 4) }] : [{ status: 1 }]);
    const res = await request(app).post('/login/verify-otp').send({ mobile_no: MOBILE, otp: OTP });
    expect(res.status).toBe(200);
    expect(jwt.verify(res.body.loginTicket, process.env.JWT_SECRET_KEY)).toMatchObject({ purpose: 'login' });
    expect(mockDb.callsTo('sp_otp', 'mark_verified')).toHaveLength(1);
  });

  test('verify-otp: wrong code → 400, attempt counted, no ticket', async () => {
    mockDb.respond = ({ inputs }) => (inputs.operation === 'verify_otp' ? [{ status: 1, otp_hash: bcrypt.hashSync(OTP, 4) }] : [{ status: 1 }]);
    const res = await request(app).post('/login/verify-otp').send({ mobile_no: MOBILE, otp: '000000' });
    expect(res.status).toBe(400);
    expect(res.body.loginTicket).toBeUndefined();
    expect(mockDb.callsTo('sp_otp', 'update_attempt')).toHaveLength(1);
  });

  test('verify-otp: expired / unknown → 400 with the database reason', async () => {
    mockDb.respond = () => [{ status: 0, message: 'OTP expired' }];
    const res = await request(app).post('/login/verify-otp').send({ mobile_no: MOBILE, otp: OTP });
    expect(res.status).toBe(400);
    expect(res.body.message).toBe('OTP expired');
  });
});

describe('phone lookups (login screens)', () => {
  test.each([
    ['checkPhoneDoctor?mobile=9876000001', 'sp_doctor_login', 'check_phone_doctor'],
    ['mobileExistDoctor?mobile=9876000001', 'sp_doctor_login', 'doctor_mobile_exist'],
    ['checkPhonePatient?mobile_no=9878000001', 'sp_patients', 'check_phone_patient'],
    ['mobileExistPatient?mobile_no=9878000001', 'sp_patients', 'patient_mobile_exist'],
    ['checkPhoneReceptionist?mobile_no=9877000001', 'sp_receptionist', 'check_phone_receptionist'],
  ])('GET /login/%s → %s:%s', async (url, proc, op) => {
    mockDb.respond = () => [{ id: 1 }];
    const res = await request(app).get('/login/' + url);
    expect(res.status).toBe(200);
    expect(mockDb.callsTo(proc, op)).toHaveLength(1);
  });
});
