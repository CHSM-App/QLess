const request = require('supertest');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

const patient = () => authHeader({ role_id: ROLE.PATIENT, uid: 9 });

// Answers the favorite-doctor reads/writes. `kind` tells a stored-procedure
// call from inline SQL, so this one responder serves both implementations:
// the suite must pass unchanged before and after sp_favorite_doctors is inlined.
function favoritesDb({ exists = false, rows = [], insertedId = 31 } = {}) {
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
    if (op === 'Delete') return [{ success: 1, message: 'Deleted successfully' }];
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

  // Pinned quirk: "already added" still answers success:true, favorite_id absent.
  test('already a favorite → still success:true, no favorite_id', async () => {
    mockDb.respond = favoritesDb({ exists: true });
    const res = await add({ patient_id: 9, doctor_id: 2, clinic_id: '4' });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, message: 'Doctor added to favorites' });
  });

  test('DB failure → 500 with the error message', async () => {
    mockDb.respond = () => { throw new Error('Violation of UNIQUE KEY constraint UQ_fav'); };
    const res = await add({ patient_id: 9, doctor_id: 2 });
    expect(res.status).toBe(500);
    expect(res.body).toEqual({ success: false, message: 'Violation of UNIQUE KEY constraint UQ_fav' });
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
