const request = require('supertest');
const { mockDb } = require('../helpers/db');
const app = require('../../src/server');

beforeEach(() => mockDb.reset());

describe('GET /health (R1)', () => {
  test('database reachable → 200 ok, no token needed', async () => {
    mockDb.respond = () => [{ ok: 1 }];
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'ok', db: 'up' });
    expect(typeof res.body.uptime).toBe('number');
  });

  test('database down → 503 with a readable body (not the generic 5xx one)', async () => {
    mockDb.respond = () => { throw new Error('connect ETIMEDOUT'); };
    const res = await request(app).get('/health');
    expect(res.status).toBe(503);
    expect(res.body).toMatchObject({ status: 'degraded', db: 'down' });
    expect(JSON.stringify(res.body)).not.toContain('ETIMEDOUT');
  });
});

// Wave 6 moved these into routes/auth/pages.js (one folder deeper).
test.each(['privacy', 'terms', 'delete-account'])('GET /login/%s still serves its page', async (page) => {
  const res = await request(app).get('/login/' + page);
  expect(res.status).toBe(200);
  expect(res.headers['content-type']).toMatch(/html/);
});
