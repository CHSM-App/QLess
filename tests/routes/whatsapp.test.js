const request = require('supertest');
const axios = require('axios');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

jest.mock('axios');

const doctor = () => authHeader({ role_id: ROLE.DOCTOR, uid: 1 });
const reception = () => authHeader({ role_id: ROLE.RECEPTIONIST, uid: 5 });
const send = (auth, body) => request(app).post('/doctor/insert/sendWhatsApp').set(auth).send(body);

const rxRows = (over = {}) => [
  { patient_name: 'Ravi', doctor_name: 'Rao', clinic_name: 'City', clinic_contact: '0231', mobile: '+91 98765 43210',
    follow_up_date: new Date('2026-12-03T00:00:00Z'), follow_up_time: '14:30', medicine_name: 'Crocin', frequency: '1-0-1', duration: '5 days', ...over },
  { medicine_name: 'Syrup', frequency: '0-0-1', duration: null },
];

beforeEach(() => {
  mockDb.reset();
  axios.post.mockReset();
  axios.post.mockResolvedValue({ data: { IsSuccess: true } });
  process.env.WHATSAPP_API_TOKEN = 'tok';
  process.env.WHATSAPP_TEMPLATE_URL = 'https://wa.example/send';
  process.env.WHATSAPP_RX_TEMPLATE_ID = '501';
  process.env.WHATSAPP_FOLLOWUP_TEMPLATE_ID = '502';
});
afterAll(() => { process.env.WHATSAPP_API_TOKEN = ''; });

test('doctor sends the prescription to the stored number', async () => {
  mockDb.respond = ({ target }) => (/prescription_vw/.test(target) ? rxRows() : []);
  const res = await send(doctor(), { appointment_id: 50, kind: 'prescription' });
  expect(res.status).toBe(200);
  const body = axios.post.mock.calls[0][1];
  expect(body).toMatchObject({ PhoneNumber: '919876543210', TemplateId: 501 });
  expect(body.Parameters).toEqual(['Ravi', 'Dr. Rao', 'City', 'Crocin 1-0-1 × 5 days; Syrup 0-0-1', '03 Dec 2026 at 02:30 PM', '0231']);
});

test('reception may send only the follow-up', async () => {
  mockDb.respond = ({ target }) => (/prescription_vw/.test(target) ? rxRows() : []);
  expect((await send(reception(), { appointment_id: 50, kind: 'prescription' })).status).toBe(403);
  const res = await send(reception(), { appointment_id: 50, kind: 'followup' });
  expect(res.status).toBe(200);
  expect(axios.post.mock.calls[0][1]).toMatchObject({ TemplateId: 502, Parameters: ['Ravi', 'Dr. Rao', 'City', '03 Dec 2026 at 02:30 PM', '0231'] });
});

test('follow-up without a date → 400, nothing sent', async () => {
  mockDb.respond = ({ target }) => (/prescription_vw/.test(target) ? rxRows({ follow_up_date: null }) : []);
  expect((await send(doctor(), { appointment_id: 50, kind: 'followup' })).status).toBe(400);
  expect(axios.post).not.toHaveBeenCalled();
});

test('bad number, no prescription, bad kind', async () => {
  mockDb.respond = ({ target }) => (/prescription_vw/.test(target) ? rxRows({ mobile: '12345' }) : []);
  expect((await send(doctor(), { appointment_id: 50, kind: 'followup' })).status).toBe(400);
  mockDb.respond = () => [];
  expect((await send(doctor(), { appointment_id: 50, kind: 'followup' })).status).toBe(404);
  expect((await send(doctor(), { appointment_id: 50, kind: 'sms' })).status).toBe(400);
  expect(axios.post).not.toHaveBeenCalled();
});

test('another doctor\'s appointment → 403 (ownStaff)', async () => {
  mockDb.owns = false;
  expect((await send(doctor(), { appointment_id: 50, kind: 'followup' })).status).toBe(403);
});
