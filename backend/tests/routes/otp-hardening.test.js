// OTP input / output hardening (security review #6, #10, verify-otp input).
jest.mock('axios');

const request = require('supertest');
const axios = require('axios');
const bcrypt = require('bcryptjs');
const { mockDb } = require('../helpers/db');
const app = require('../../src/server');

beforeAll(() => { process.env.WHATSAPP_API_TOKEN = 'test-token'; });
afterAll(() => { process.env.WHATSAPP_API_TOKEN = ''; });
beforeEach(() => {
  mockDb.reset();
  mockDb.respond = () => [{ status: 1 }];
  axios.post.mockResolvedValue({ data: { IsSuccess: true } });
});

test('a provider refusal is not echoed to the caller', async () => {
  axios.post.mockResolvedValue({ data: { IsSuccess: false, Detail: 'internal provider info' } });
  const res = await request(app).post('/login/send-otp').send({ mobile_no: '9123400000' });
  expect(res.status).toBe(400);
  expect(res.body.response).toBeUndefined();
  expect(JSON.stringify(res.body)).not.toContain('internal provider info');
});

test('verify-otp without an otp → 400, not a 500 from bcrypt', async () => {
  const res = await request(app).post('/login/verify-otp').send({ mobile_no: '9123400000' });
  expect(res.status).toBe(400);
  expect(mockDb.calls).toHaveLength(0);
});

test('verify-otp normalizes the number to the key send-otp stored', async () => {
  const otp_hash = await bcrypt.hash('123456', 4);
  mockDb.respond = ({ inputs }) => (inputs.operation === 'verify_otp' ? [{ status: 1, otp_hash }] : [{ status: 1 }]);
  const res = await request(app).post('/login/verify-otp').send({ mobile_no: '+91 91234 00000', otp: '123456' });
  expect(res.status).toBe(200);
  expect(res.body.loginTicket).toBeTruthy();
  for (const call of mockDb.calls) expect(call.inputs.mobile_no).toBe('9123400000');
});
