const request = require('supertest');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

const doctor = () => authHeader({ role_id: ROLE.DOCTOR, uid: 1 });
const recep = () => authHeader({ role_id: ROLE.RECEPTIONIST, uid: 7 });
const UUID = '3f2b8c1e-9a4d-4e2b-8f6a-1c2d3e4f5a6b';

beforeEach(() => mockDb.reset());

describe('/doctor/stock access', () => {
  test('patients are refused', async () => {
    const res = await request(app).get('/doctor/stock/CL001').set(authHeader({ role_id: ROLE.PATIENT, uid: 4 }));
    expect(res.status).toBe(403);
  });

  test("another doctor's clinic is refused", async () => {
    mockDb.owns = false;
    expect((await request(app).get('/doctor/stock/CL999').set(doctor())).status).toBe(403);
    expect((await request(app).post('/doctor/stock/movement').set(doctor())
      .send({ clinic_id: 'CL999', medicine_id: 3, qty: 10, reason: 'purchase' })).status).toBe(403);
  });
});

describe('GET /doctor/stock/:clinic_id', () => {
  test('lists the clinic stock', async () => {
    mockDb.respond = () => [{ medicine_id: 3, balance: -2, is_low: 1 }];
    const res = await request(app).get('/doctor/stock/CL001').set(recep());
    expect(res.body).toEqual({ success: true, data: [{ medicine_id: 3, balance: -2, is_low: 1 }] });
    expect(mockDb.callsTo('FROM dbo.Clinic_Medicine cm')[0].inputs.clinic_id).toBe('CL001');
  });

  test('movements filter by medicine', async () => {
    await request(app).get('/doctor/stock/CL001/movements?medicine_id=3').set(doctor());
    expect(mockDb.callsTo('FROM dbo.Clinic_Stock_Movement m')[0].inputs).toMatchObject({ clinic_id: 'CL001', medicine_id: 3 });
    expect((await request(app).get('/doctor/stock/CL001/movements?medicine_id=x').set(doctor())).status).toBe(400);
  });
});

describe('PUT /doctor/stock/item', () => {
  const put = (body) => request(app).put('/doctor/stock/item').set(doctor()).send(body);

  test('saves unit, reorder level and price', async () => {
    mockDb.respond = () => [{ n: 1 }];
    const res = await put({ clinic_id: 'CL001', medicine_id: 3, unit: 'tablet', reorder_level: 20, sale_price: 2.5 });
    expect(res.status).toBe(200);
    expect(mockDb.callsTo('UPDATE dbo.Clinic_Medicine')[0].inputs)
      .toMatchObject({ clinic_id: 'CL001', medicine_id: 3, unit: 'tablet', reorder_level: 20, sale_price: 2.5 });
  });

  test('unknown medicine → 404, negative price → 400', async () => {
    mockDb.respond = () => [{ n: 0 }];
    expect((await put({ clinic_id: 'CL001', medicine_id: 999 })).status).toBe(404);
    expect((await put({ clinic_id: 'CL001', medicine_id: 3, sale_price: -1 })).status).toBe(400);
  });
});

describe('POST /doctor/stock/movement', () => {
  const move = (body, who = recep()) => request(app).post('/doctor/stock/movement').set(who)
    .send({ clinic_id: 'CL001', medicine_id: 3, ...body });

  test('purchase records who did it and returns the balance', async () => {
    mockDb.respond = () => [{ movement_id: 11, balance: 48 }];
    const res = await move({ qty: 50, reason: 'purchase', unit_cost: 1.2, client_uuid: UUID });
    expect(res.body).toEqual({ success: true, movement_id: 11, balance: 48 });
    expect(mockDb.callsTo('INSERT INTO dbo.Clinic_Stock_Movement')[0].inputs).toMatchObject({
      qty: 50, reason: 'purchase', unit_cost: 1.2, client_uuid: UUID, created_by_id: 7, created_by_role: ROLE.RECEPTIONIST,
    });
  });

  test('adjust may be negative; purchase may not', async () => {
    mockDb.respond = () => [{ movement_id: 12, balance: 40 }];
    expect((await move({ qty: -8, reason: 'adjust', note: 'expired' })).status).toBe(200);
    expect((await move({ qty: -8, reason: 'purchase' })).status).toBe(400);
  });

  test.each([
    [{ qty: 0, reason: 'adjust' }],
    [{ qty: 'abc', reason: 'adjust' }],
    [{ qty: 5, reason: 'dispense' }], // only prescriptions dispense
    [{ qty: 5, reason: 'purchase', client_uuid: 'not-a-uuid' }],
    [{ qty: 5, reason: 'purchase', expiry_date: 'someday' }],
    [{ qty: 5, reason: 'purchase', medicine_id: undefined }],
  ])('400 for %j', async (body) => {
    expect((await move(body)).status).toBe(400);
  });

  test('unknown medicine → 404', async () => {
    mockDb.respond = () => [{ movement_id: null }];
    expect((await move({ qty: 5, reason: 'purchase' })).status).toBe(404);
  });

  test('the same offline change sent twice is recorded once', async () => {
    mockDb.respond = () => {
      const err = new Error("Cannot insert duplicate key row in object 'dbo.Clinic_Stock_Movement' with unique index 'UX_Clinic_Stock_Movement_client_uuid'.");
      err.number = 2601;
      throw err;
    };
    const res = await move({ qty: 5, reason: 'purchase', client_uuid: UUID });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ success: true, duplicate: true });
  });
});
