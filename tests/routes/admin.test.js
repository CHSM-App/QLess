const request = require('supertest');
const jwt = require('jsonwebtoken');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

const ADMIN = { username: 'support', password: 'correct-horse-battery-staple' };
const admin = () => authHeader({ role_id: ROLE.ADMIN, uid: 'admin' });

beforeEach(() => {
  mockDb.reset();
  process.env.ADMIN_USERNAME = ADMIN.username;
  process.env.ADMIN_PASSWORD = ADMIN.password;
});

describe('POST /admin/login', () => {
  test('right credentials → 4h admin token', async () => {
    const res = await request(app).post('/admin/login').send(ADMIN);
    expect(res.status).toBe(200);
    const token = jwt.verify(res.body.accessToken, process.env.JWT_SECRET_KEY);
    expect(token).toMatchObject({ role_id: ROLE.ADMIN, uid: 'admin' });
    expect(token.exp - token.iat).toBe(4 * 3600);
  });

  test.each([
    ['wrong password', { ...ADMIN, password: 'nope' }],
    ['wrong username', { ...ADMIN, username: 'root' }],
    ['password of a different length', { ...ADMIN, password: ADMIN.password + 'x' }],
    ['missing fields', {}],
  ])('%s → 401', async (_, body) => {
    const res = await request(app).post('/admin/login').send(body);
    expect(res.status).toBe(401);
    expect(res.body.accessToken).toBeUndefined();
  });

  test('500 when the admin credential is not configured', async () => {
    delete process.env.ADMIN_PASSWORD;
    const res = await request(app).post('/admin/login').send(ADMIN);
    expect(res.status).toBe(500);
    expect(res.body.accessToken).toBeUndefined();
  });
});

describe('admin-only routes', () => {
  const ROUTES = [
    ['get', '/admin/doctors/pending'],
    ['post', '/admin/doctors/5/verify'],
    ['post', '/admin/doctors/5/reject'],
  ];

  test.each(ROUTES)('%s %s → 401 without a token', async (method, url) => {
    expect((await request(app)[method](url)).status).toBe(401);
  });

  test.each(ROUTES)('%s %s → 403 for a doctor token', async (method, url) => {
    const res = await request(app)[method](url).set(authHeader({ role_id: ROLE.DOCTOR }));
    expect(res.status).toBe(403);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('pending list comes from ListPendingDoctors', async () => {
    mockDb.respond = ({ target, inputs }) =>
      (target === 'sp_doctor_login' && inputs.operation === 'ListPendingDoctors' ? [{ doctor_id: 5, name: 'Dr A' }] : []);
    const res = await request(app).get('/admin/doctors/pending').set(admin());
    expect(res.body).toEqual([{ doctor_id: 5, name: 'Dr A' }]);
  });

  test.each([['verify', 'VerifyDoctor'], ['reject', 'DeleteDoctor']])('%s → %s for that doctor', async (action, operation) => {
    mockDb.respond = () => [{ success: 1, message: 'done' }];
    const res = await request(app).post(`/admin/doctors/5/${action}`).set(admin());

    expect(res.body).toEqual({ success: 1, message: 'done' });
    expect(mockDb.callsTo('sp_doctor_login', operation)[0].inputs.doctor_id).toBe(5);
  });

  test('empty procedure result → { success: true }', async () => {
    const res = await request(app).post('/admin/doctors/5/verify').set(admin());
    expect(res.body).toEqual({ success: true });
  });

  test('non-numeric id → 400, no DB call', async () => {
    const res = await request(app).post('/admin/doctors/abc/verify').set(admin());
    expect(res.status).toBe(400);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('DB failure → 500', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    const res = await request(app).get('/admin/doctors/pending').set(admin());
    expect(res.status).toBe(500);
  });
});
