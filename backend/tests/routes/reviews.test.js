const request = require('supertest');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

const patient = () => authHeader({ role_id: ROLE.PATIENT, uid: 9 });

// One responder for both implementations (sp_review and its inline SQL), so
// this suite passes unchanged before and after the move.
function reviewsDb({ completed = true, alreadyReviewed = false, rows = [], newId = 12 } = {}) {
  return ({ kind, target, inputs }) => {
    const sp = kind === 'execute' && target === 'sp_review' ? inputs.operation : null;
    const op = sp === 'Fetch' ? (inputs.appointment_id != null ? 'FetchOne' : 'FetchDoctor')
      : sp
        || (/INSERT INTO reviews/.test(target) ? 'Insert'
          : /DELETE FROM reviews/.test(target) ? 'Delete'
            : /LEFT JOIN family_members/.test(target) ? 'FetchDoctor'
              : /FROM reviews/.test(target) ? 'FetchOne' : null);
    if (op === 'Insert') {
      if (!completed) return [{ success: 0, message: 'Appointment not completed or invalid' }];
      if (alreadyReviewed) return [{ success: 0, message: 'Review already submitted' }];
      return [{ success: 1, review_id: newId, message: 'Review added' }];
    }
    if (op === 'Delete') return [{ success: 1, message: 'Review deleted' }];
    if (op === 'FetchOne' || op === 'FetchDoctor') return rows;
    return [];
  };
}
const reviewCall = () => mockDb.calls.find((c) => c.target === 'sp_review' || /reviews/.test(c.target));

beforeEach(() => mockDb.reset());

describe('POST /patient/insert/review/add', () => {
  const valid = { appointment_id: 50, doctor_id: 2, patient_id: 9, rating: 3.5, comment: 'Good', reviewed_by_user_id: 9, clinic_id: 'CL002' };
  const add = (body) => request(app).post('/patient/insert/review/add').set(patient()).send(body);

  test.each(['appointment_id', 'doctor_id', 'patient_id', 'rating', 'reviewed_by_user_id'])(
    '400 without %s, no DB call', async (field) => {
      const res = await add({ ...valid, [field]: undefined });
      expect(res.status).toBe(400);
      expect(mockDb.calls).toHaveLength(0);
    });

  test('adds the review and returns its id', async () => {
    mockDb.respond = reviewsDb({ newId: 12 });
    const res = await add(valid);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: 1, message: 'Review added', review_id: 12 });
    expect(reviewCall().inputs).toMatchObject({
      appointment_id: 50, doctor_id: 2, patient_id: 9, rating: 3.5, comment: 'Good', reviewed_by_user_id: 9, clinic_id: 'CL002',
    });
  });

  test('missing comment is sent as empty string, missing clinic_id as NULL', async () => {
    mockDb.respond = reviewsDb();
    await add({ ...valid, comment: undefined, clinic_id: undefined });
    expect(reviewCall().inputs).toMatchObject({ comment: '', clinic_id: null });
  });

  test.each([
    ['appointment not completed', { completed: false }, 'Appointment not completed or invalid'],
    ['already reviewed', { alreadyReviewed: true }, 'Review already submitted'],
  ])('%s → 200 with success 0 and the reason', async (_, scenario, message) => {
    mockDb.respond = reviewsDb(scenario);
    const res = await add(valid);
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: 0, message });
  });

  test('B6: a comment over 500 characters → 400 instead of being cut', async () => {
    const res = await add({ ...valid, comment: 'x'.repeat(501) });
    expect(res.status).toBe(400);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('B5: the review and is_reviewed are written in one transaction', async () => {
    mockDb.respond = reviewsDb();
    await add(valid);
    const sqlText = reviewCall().target;
    expect(sqlText).toMatch(/SET XACT_ABORT ON/);
    expect(sqlText.indexOf('BEGIN TRANSACTION')).toBeLessThan(sqlText.indexOf('INSERT INTO reviews'));
    expect(sqlText.indexOf('UPDATE appointments')).toBeLessThan(sqlText.indexOf('COMMIT TRANSACTION'));
  });

  test('DB failure → 500, generic message (S7)', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    const res = await add(valid);
    expect(res.status).toBe(500);
    expect(res.body).toMatchObject({ success: false, message: 'Something went wrong. Please try again.' });
    expect(res.body.correlation_id).toBeTruthy();
    expect(JSON.stringify(res.body)).not.toContain('db down');
  });
});

describe('DELETE /patient/index/review/:appointment_id/:patient_id', () => {
  test('deletes and answers 200', async () => {
    mockDb.respond = reviewsDb();
    const res = await request(app).delete('/patient/index/review/50/9').set(patient());

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, message: 'Review deleted' });
    expect(reviewCall().inputs).toMatchObject({ appointment_id: 50, patient_id: 9 });
  });

  test('DB failure → 500', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    const res = await request(app).delete('/patient/index/review/50/9').set(patient());
    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
  });
});

describe('GET /patient/users/review/appointment/:appointment_id', () => {
  test('returns the review rows for that appointment', async () => {
    const rows = [{ review_id: 12, appointment_id: 50, rating: 3.5, comment: 'Good' }];
    mockDb.respond = reviewsDb({ rows });
    const res = await request(app).get('/patient/users/review/appointment/50').set(patient());

    expect(res.body).toEqual(rows);
    expect(reviewCall().inputs.appointment_id).toBe('50');
  });

  test('no review → []', async () => {
    mockDb.respond = reviewsDb();
    const res = await request(app).get('/patient/users/review/appointment/50').set(patient());
    expect(res.body).toEqual([]);
  });

  test('DB failure → 500', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    expect((await request(app).get('/patient/users/review/appointment/50').set(patient())).status).toBe(500);
  });
});

describe('GET /patient/users/review/doctor/:doctor_id/:clinic_id', () => {
  test('returns the doctor review list as a plain array', async () => {
    const rows = [{ review_id: 12, doctor_id: 2, reviewed_by_name: 'Asha', patient_name: 'Ravi', rating: 4.5 }];
    mockDb.respond = reviewsDb({ rows });
    const res = await request(app).get('/patient/users/review/doctor/2/CL002').set(patient());

    expect(res.body).toEqual(rows);
    expect(reviewCall().inputs).toMatchObject({ doctor_id: '2', clinic_id: 'CL002' });
  });

  test('DB failure → 500', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    expect((await request(app).get('/patient/users/review/doctor/2/CL002').set(patient())).status).toBe(500);
  });
});

// B4: patient and family-member ids are separate sequences, so comparing
// r.patient_id with the reviewer could name the wrong person.
test('B4: the reviewed person (self or family) comes from the appointment', async () => {
  mockDb.respond = reviewsDb();
  await request(app).get('/patient/users/review/doctor/2/CL002').set(patient());
  const sqlText = mockDb.calls.find((c) => /LEFT JOIN family_members/.test(c.target)).target;
  expect(sqlText).toMatch(/LEFT JOIN appointments a ON a\.appointment_id = r\.appointment_id/);
  expect(sqlText).toMatch(/CASE WHEN a\.user_type = 2 THEN fm\.name ELSE p\.name END AS patient_name/);
});
