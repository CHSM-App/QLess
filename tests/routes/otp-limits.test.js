// S13: OTP sending / verifying is rate-limited per mobile number (and sending
// per IP). Uses the REAL limiters, not the no-op mock from tests/setup.js.
jest.unmock('../../src/middleware/rateLimit');
jest.mock('axios');

const request = require('supertest');
const axios = require('axios');
const { mockDb } = require('../helpers/db');
const app = require('../../src/server');

beforeAll(() => { process.env.WHATSAPP_API_TOKEN = 'test-token'; });
afterAll(() => { process.env.WHATSAPP_API_TOKEN = ''; });
beforeEach(() => {
  mockDb.reset();
  mockDb.respond = () => [{ status: 1 }];
  axios.post.mockResolvedValue({ data: { IsSuccess: true } });
});

const send = (mobile) => request(app).post('/login/send-otp').send({ mobile_no: mobile });

test('4th OTP to the same number within 15 min → 429, no 4th WhatsApp message', async () => {
  for (let i = 0; i < 3; i++) expect((await send('9111111111')).status).toBe(200);
  axios.post.mockClear();
  const res = await send('+91 91111 11111'); // same number, typed differently
  expect(res.status).toBe(429);
  expect(axios.post).not.toHaveBeenCalled();
});

test('a different number still gets its OTP', async () => {
  expect((await send('9222222222')).status).toBe(200);
});

test('one IP is capped at 10 sends an hour across numbers', async () => {
  // 5 requests from this IP so far (the refused one counts too); 5 more reach the cap
  for (let i = 0; i < 5; i++) expect((await send(`93333333${String(i).padStart(2, '0')}`)).status).toBe(200);
  expect((await send('9444444444')).status).toBe(429);
});

test('verify: 11th attempt for one number within 15 min → 429', async () => {
  mockDb.respond = () => [{ status: 0, message: 'OTP expired' }];
  for (let i = 0; i < 10; i++) expect((await request(app).post('/login/verify-otp').send({ mobile_no: '9555555555', otp: '000000' })).status).toBe(400);
  expect((await request(app).post('/login/verify-otp').send({ mobile_no: '9555555555', otp: '000000' })).status).toBe(429);
});

test('account-deletion OTPs share the per-number budget', async () => {
  for (let i = 0; i < 3; i++) await request(app).post('/delete-account/request').send({ phone: '9666666666', role_id: 2 });
  const res = await request(app).post('/delete-account/request').send({ phone: '9666666666', role_id: 2 });
  expect(res.status).toBe(429);
});
