const request = require('supertest');
const bcrypt = require('bcryptjs');
const axios = require('axios');
const { mockDb } = require('../helpers/db');
const app = require('../../src/server');

jest.mock('axios');

const PHONE = '9123456789';
const DEMO_PHONE = '9878000001';
const OTP = '654321';
const OTP_HASH = bcrypt.hashSync(OTP, 4);

// Fake DB: sp_otp holds OTP_HASH for PHONE; `pending` = an existing request.
function accountDb({ pending = null, otpRow = { status: 1, otp_hash: OTP_HASH } } = {}) {
  return ({ kind, target, inputs }) => {
    if (target === 'sp_otp' && inputs.operation === 'send_otp') return [{ status: 1 }];
    if (target === 'sp_otp' && inputs.operation === 'verify_otp') return otpRow ? [otpRow] : [];
    if (kind === 'query' && target.includes('FROM AccountDeletionRequests')) return pending ? [pending] : [];
    return [];
  };
}
const otpCalls = (op) => mockDb.callsTo('sp_otp', op);
const insertCalls = () => mockDb.calls.filter((c) => c.kind === 'query' && c.target.includes('INSERT INTO AccountDeletionRequests'));

beforeEach(() => {
  mockDb.reset();
  axios.post.mockReset();
  axios.post.mockResolvedValue({ data: { IsSuccess: true } });
  process.env.WHATSAPP_API_TOKEN = 'test-token';
});
afterAll(() => { process.env.WHATSAPP_API_TOKEN = ''; });

describe('validation (all three routes)', () => {
  test.each(['/request', '/confirm', '/cancel'])('%s: bad phone / role / otp → 400, no DB call', async (route) => {
    const post = (body) => request(app).post('/delete-account' + route).send(body);
    expect((await post({ phone: '12345', role_id: 2, otp: OTP })).status).toBe(400);
    expect((await post({ phone: PHONE, role_id: 9, otp: OTP })).status).toBe(400);
    if (route !== '/request') expect((await post({ phone: PHONE, role_id: 2, otp: '12' })).status).toBe(400);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('phone formats +91 / leading 0 are normalised', async () => {
    mockDb.respond = accountDb();
    await request(app).post('/delete-account/request').send({ phone: '+91 91234 56789', role_id: 2 });
    expect(otpCalls('send_otp')[0].inputs.mobile_no).toBe(PHONE);
  });
});

describe('POST /delete-account/request', () => {
  test('sends a WhatsApp OTP and stores only its hash', async () => {
    mockDb.respond = accountDb();
    const res = await request(app).post('/delete-account/request').send({ phone: PHONE, role_id: 2 });

    expect(res.body.success).toBe(true);
    const sent = axios.post.mock.calls[0][1];
    expect(sent.PhoneNumber).toBe('91' + PHONE);
    const stored = otpCalls('send_otp')[0].inputs.otp_hash;
    expect(stored).not.toBe(sent.OtpCode);
    expect(bcrypt.compareSync(sent.OtpCode, stored)).toBe(true);
  });

  // S8: the OTP must never be in the response, in any environment.
  test.each(['development', 'test', 'production'])('NODE_ENV=%s → no OTP in the response', async (env) => {
    const saved = process.env.NODE_ENV;
    process.env.NODE_ENV = env;
    try {
      mockDb.respond = accountDb();
      const res = await request(app).post('/delete-account/request').send({ phone: PHONE, role_id: 2 });
      const otp = axios.post.mock.calls[0][1].OtpCode;
      expect(res.body.dev_otp).toBeUndefined();
      expect(JSON.stringify(res.body)).not.toContain(otp);
    } finally { process.env.NODE_ENV = saved; }
  });

  test('WhatsApp failure still answers 200 (no account enumeration)', async () => {
    axios.post.mockResolvedValue({ data: { IsSuccess: false } });
    const res = await request(app).post('/delete-account/request').send({ phone: PHONE, role_id: 2 });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(otpCalls('send_otp')).toHaveLength(0);
  });

  test('demo phones never send an SMS', async () => {
    const res = await request(app).post('/delete-account/request').send({ phone: DEMO_PHONE, role_id: 2 });
    expect(res.body.success).toBe(true);
    expect(axios.post).not.toHaveBeenCalled();
  });
});

describe('POST /delete-account/confirm', () => {
  const confirm = (body = {}) => request(app).post('/delete-account/confirm')
    .send({ phone: PHONE, role_id: 2, otp: OTP, reason: 'moving', ...body });

  test('valid OTP → pending request scheduled 30 days out', async () => {
    mockDb.respond = accountDb();
    const res = await confirm();

    expect(res.body.success).toBe(true);
    const days = (new Date(res.body.scheduled_for) - Date.now()) / 86400000;
    expect(days).toBeGreaterThan(29.9);
    expect(days).toBeLessThan(30.1);
    expect(insertCalls()[0].inputs).toMatchObject({ phone: PHONE, role_id: 2, reason: 'moving' });
    expect(otpCalls('mark_verified')).toHaveLength(1);
  });

  test('wrong OTP → 400, attempt counted, nothing scheduled', async () => {
    mockDb.respond = accountDb();
    const res = await confirm({ otp: '111111' });

    expect(res.status).toBe(400);
    expect(otpCalls('update_attempt')).toHaveLength(1);
    expect(insertCalls()).toHaveLength(0);
  });

  test('expired / unknown OTP → 400', async () => {
    mockDb.respond = accountDb({ otpRow: { status: 0 } });
    expect((await confirm()).status).toBe(400);
    expect(insertCalls()).toHaveLength(0);
  });

  test('already pending → 409 with the existing date, no second row', async () => {
    mockDb.respond = accountDb({ pending: { id: 3, scheduled_for: '2026-12-20T00:00:00.000Z' } });
    const res = await confirm();

    expect(res.status).toBe(409);
    expect(res.body.scheduled_for).toBe('2026-12-20T00:00:00.000Z');
    expect(insertCalls()).toHaveLength(0);
  });

  test('reason is cut to 500 characters', async () => {
    mockDb.respond = accountDb();
    await confirm({ reason: 'x'.repeat(900) });
    expect(insertCalls()[0].inputs.reason).toHaveLength(500);
  });

  test('demo phone: right demo OTP is a harmless no-op, wrong one → 400', async () => {
    const ok = await confirm({ phone: DEMO_PHONE, otp: '123456' });
    expect(ok.body.success).toBe(true);
    expect((await confirm({ phone: DEMO_PHONE, otp: '000000' })).status).toBe(400);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('DB failure → 500 with a generic message', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    const res = await confirm();
    expect(res.status).toBe(500);
    expect(res.body.message).not.toMatch(/db down/);
  });
});

describe('POST /delete-account/cancel', () => {
  const cancel = (body = {}) => request(app).post('/delete-account/cancel')
    .send({ phone: PHONE, role_id: 2, otp: OTP, ...body });
  const cancelUpdates = () => mockDb.calls.filter((c) => c.kind === 'query' && c.target.includes("SET status = 'cancelled'"));

  test('valid OTP + pending request → cancelled', async () => {
    mockDb.respond = accountDb({ pending: { id: 3 } });
    const res = await cancel();

    expect(res.body.success).toBe(true);
    expect(cancelUpdates()[0].inputs.id).toBe(3);
  });

  test('no pending request → 404', async () => {
    mockDb.respond = accountDb();
    expect((await cancel()).status).toBe(404);
    expect(cancelUpdates()).toHaveLength(0);
  });

  test('wrong OTP → 400, nothing cancelled', async () => {
    mockDb.respond = accountDb({ pending: { id: 3 } });
    expect((await cancel({ otp: '111111' })).status).toBe(400);
    expect(cancelUpdates()).toHaveLength(0);
  });
});
