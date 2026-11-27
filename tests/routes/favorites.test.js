const request = require('supertest');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

const patient = () => authHeader({ role_id: ROLE.PATIENT, uid: 9 });

// Answers the favorite-doctor reads/writes. `kind` tells a stored-procedure
// call from inline SQL, so this one responder serves both implementations:
// the suite must pass unchanged before and after sp_favorite_doctors is inlined.
function favoritesDb({ exists = false, rows = [], insertedId = 31, deleted = 1 } = {}) {
  return ({ kind, target, inputs }) => {
    const op = kind === 'execute' && target === 'sp_favorite_doctors' ? inputs.operation
      : kind === 'query' && /INSERT INTO favorite_doctors/.test(target) ? 'Insert'
        : kind === 'query' && /DELETE FROM favorite_doctors/.test(target) ? 'Delete'
          : kind === 'query' && /FROM favorite_doctors/.test(target) ? 'Fetch'
            : null;
    if (op === 'Insert') {
      return exists
        ? [{ success: 0, message: 'Already added to favorites' }]
        : [{ success: 1, favorite_id: insertedId, message: 'Added successfully' }];
    }
    if (op === 'Delete') return [{ deleted }];
    if (op === 'Fetch' && inputs.doctor_id != null) return [{ is_favorite: exists ? 1 : 0 }];
    if (op === 'Fetch') return rows;
    return [];
  };
}

// The inputs the database saw, whichever implementation ran.
const favCall = () => mockDb.calls.find((c) => c.target === 'sp_favorite_doctors' || /favorite_doctors/.test(c.target));

beforeEach(() => mockDb.reset());

describe('POST /patient/insert/favoriteDoctor/add', () => {
  const add = (body) => request(app).post('/patient/insert/favoriteDoctor/add').set(patient()).send(body);

  test('400 without patient_id or doctor_id, no DB call', async () => {
    expect((await add({ doctor_id: 2 })).status).toBe(400);
    expect((await add({ patient_id: 9 })).status).toBe(400);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('adds and returns the new favorite_id', async () => {
    mockDb.respond = favoritesDb({ insertedId: 31 });
    const res = await add({ patient_id: 9, doctor_id: 2, clinic_id: '4' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, message: 'Doctor added to favorites', favorite_id: 31 });
    expect(favCall().inputs).toMatchObject({ patient_id: 9, doctor_id: 2, clinic_id: '4' });
  });

  test('missing clinic_id is sent as NULL', async () => {
    mockDb.respond = favoritesDb();
    await add({ patient_id: 9, doctor_id: 2 });
    expect(favCall().inputs.clinic_id).toBeNull();
  });

  // B1: the app treats it as success; `already` tells it nothing was added.
  test('already a favorite → success:true, already:true, no favorite_id', async () => {
    mockDb.respond = favoritesDb({ exists: true });
    const res = await add({ patient_id: 9, doctor_id: 2, clinic_id: '4' });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, already: true, message: 'Doctor is already in your favorites' });
  });

  // B2: "clinic_id = NULL" never matched, so the second add hit UQ_fav → 500.
  test('the exists check compares clinic_id NULL-safely', async () => {
    mockDb.respond = favoritesDb({ exists: true });
    await add({ patient_id: 9, doctor_id: 2 });
    expect(favCall().target).toMatch(/clinic_id IS NULL AND @clinic_id IS NULL/);
  });

  test('DB failure → 500, no SQL details in the response (S7)', async () => {
    mockDb.respond = () => { throw new Error('Violation of UNIQUE KEY constraint UQ_fav'); };
    const res = await add({ patient_id: 9, doctor_id: 2 });
    expect(res.status).toBe(500);
    expect(res.body).toMatchObject({ success: false, message: 'Something went wrong. Please try again.' });
    expect(res.body.correlation_id).toBeTruthy();
    expect(JSON.stringify(res.body)).not.toContain('UQ_fav');
  });
});

describe('DELETE /patient/index/favoriteDoctor/:patient_id/:doctor_id/:clinic_id', () => {
  test('deletes and answers 200', async () => {
    mockDb.respond = favoritesDb();
    const res = await request(app).delete('/patient/index/favoriteDoctor/9/2/4').set(patient());

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, message: 'Deleted successfully' });
    expect(favCall().inputs).toMatchObject({ patient_id: 9, doctor_id: 2, clinic_id: '4' });
  });

  // B3: deleting nothing used to answer 200 "Deleted successfully".
  test('not a favorite → 404', async () => {
    mockDb.respond = favoritesDb({ deleted: 0 });
    const res = await request(app).delete('/patient/index/favoriteDoctor/9/2/4').set(patient());
    expect(res.status).toBe(404);
    expect(res.body).toEqual({ success: false, message: 'This doctor is not in your favorites' });
  });

  // B2: a favorite saved without a clinic arrives as "null" in the URL.
  test('"null" clinic in the URL is deleted as NULL', async () => {
    mockDb.respond = favoritesDb();
    const res = await request(app).delete('/patient/index/favoriteDoctor/9/2/null').set(patient());
    expect(res.status).toBe(200);
    expect(favCall().inputs.clinic_id).toBeNull();
    expect(favCall().target).toMatch(/clinic_id IS NULL AND @clinic_id IS NULL/);
  });

  test('DB failure → 500', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    const res = await request(app).delete('/patient/index/favoriteDoctor/9/2/4').set(patient());
    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});

describe('GET /patient/users/favoriteDoctors/:patient_id', () => {
  test('returns the rows as a plain array', async () => {
    const rows = [{ favorite_id: 31, patient_id: 9, doctor_id: 2, clinic_id: '4', is_favorite: true }];
    mockDb.respond = favoritesDb({ rows });
    const res = await request(app).get('/patient/users/favoriteDoctors/9').set(patient());

    expect(res.body).toEqual(rows);
    expect(favCall().inputs.patient_id).toBe('9');
  });

  test('no favorites → []', async () => {
    mockDb.respond = favoritesDb();
    const res = await request(app).get('/patient/users/favoriteDoctors/9').set(patient());
    expect(res.body).toEqual([]);
  });
});

describe('GET /patient/users/favoriteDoctor/:patient_id/:doctor_id/:clinic_id', () => {
  test.each([[true, 1], [false, 0]])('favorite=%s → is_favorite %i', async (exists, expected) => {
    mockDb.respond = favoritesDb({ exists });
    const res = await request(app).get('/patient/users/favoriteDoctor/9/2/4').set(patient());

    expect(res.body).toEqual({ is_favorite: expected });
    expect(favCall().inputs).toMatchObject({ patient_id: '9', doctor_id: '2', clinic_id: '4' });
  });

  test('DB failure → 500', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    const res = await request(app).get('/patient/users/favoriteDoctor/9/2/4').set(patient());
    expect(res.status).toBe(500);
  });
});
