const request = require('supertest');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const app = require('../../src/server');

const patient = () => authHeader({ role_id: ROLE.PATIENT, uid: 9 });

// One responder for both implementations (sp_family_members and the inline
// SQL), so the suite passes unchanged before and after the move.
function familyDb({ newId = 41, rows = [], error = null, updated = 1, referenced = false } = {}) {
  return ({ kind, target, inputs }) => {
    const op = kind === 'execute' && target === 'sp_family_members' ? inputs.operation
      : /INSERT INTO dbo\.family_members/.test(target) ? 'Insert'
        : /UPDATE dbo\.family_members/.test(target) ? 'Update'
          : /DELETE FROM dbo\.family_members/.test(target) ? 'DeleteMember'
            : /LEFT JOIN Relations/.test(target) ? 'AllFamilyMembers' : null;
    if ((op === 'Insert' || op === 'Update') && error) return [{ ErrorMessage: error, ErrorLine: 1 }];
    if (op === 'Insert') return [{ member_id: newId }];
    if (op === 'Update') return [{ member_id: inputs.member_id, updated }];
    if (op === 'DeleteMember') {
      return referenced
        ? [{ success: 0, message: 'Member is used in other records, cannot delete.' }]
        : [{ success: 1, message: 'Member deleted successfully' }];
    }
    if (op === 'AllFamilyMembers') return rows;
    return [];
  };
}
const famCall = () => mockDb.calls.find((c) => c.target === 'sp_family_members' || /family_members/.test(c.target));

beforeEach(() => mockDb.reset());

describe('POST /patient/insert/insertFamilyMember', () => {
  const member = { family_id: 9, name: 'Ravi', Gender_id: 1, relation_id: 3, DOB: '2015-06-01', mobile_no: '9000011111' };
  const save = (body) => request(app).post('/patient/insert/insertFamilyMember').set(patient()).send(body);

  test('no member_id → adds and returns the new id', async () => {
    mockDb.respond = familyDb({ newId: 41 });
    const res = await save(member);

    expect(res.body).toEqual({ success: true, member_id: 41, message: 'Family member added successfully' });
    expect(famCall().inputs).toMatchObject({ ...member, member_id: null });
  });

  test('member_id 0 is treated as a new member', async () => {
    mockDb.respond = familyDb({ newId: 42 });
    const res = await save({ ...member, member_id: 0 });
    expect(res.body.message).toBe('Family member added successfully');
  });

  test('member_id > 0 → updates and returns that id', async () => {
    mockDb.respond = familyDb();
    const res = await save({ ...member, member_id: 41 });

    expect(res.body).toEqual({ success: true, member_id: 41, message: 'Family member updated successfully' });
    expect(famCall().inputs).toMatchObject({ member_id: 41, name: 'Ravi' });
  });

  test('empty strings / missing optional fields are sent as NULL', async () => {
    mockDb.respond = familyDb();
    await save({ family_id: 9, name: '', mobile_no: '', Gender_id: 0 });
    expect(famCall().inputs).toMatchObject({ name: null, mobile_no: null, Gender_id: null, relation_id: null, DOB: null });
  });

  test('SQL error caught by the database → 500, details only in the log (S7)', async () => {
    mockDb.respond = familyDb({ error: 'Cannot insert the value NULL into column family_id' });
    const res = await save(member);
    expect(res.status).toBe(500);
    expect(res.body).toMatchObject({ success: false, message: 'Something went wrong. Please try again.' });
    expect(res.body.correlation_id).toBeTruthy();
    expect(JSON.stringify(res.body)).not.toContain('Cannot insert the value NULL');
    expect(res.body.error).toBe('Something went wrong. Please try again.');
  });

  test('B8: no family_id → 400, nothing written', async () => {
    const res = await save({ ...member, family_id: undefined });
    expect(res.status).toBe(400);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('B8: updating a member that does not exist → 404', async () => {
    mockDb.respond = familyDb({ updated: 0 });
    const res = await save({ ...member, member_id: 999 });
    expect(res.status).toBe(404);
    expect(res.body).toEqual({ success: false, message: 'Family member not found' });
  });

  test('B9: a name over 100 characters → 400 instead of being cut', async () => {
    const res = await save({ ...member, name: 'x'.repeat(101) });
    expect(res.status).toBe(400);
    expect(mockDb.calls).toHaveLength(0);
  });

  test('connection failure → 500, generic message (S7)', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    const res = await save(member);
    expect(res.status).toBe(500);
    expect(res.body).toMatchObject({ success: false, message: 'Something went wrong. Please try again.' });
    expect(res.body.correlation_id).toBeTruthy();
    expect(JSON.stringify(res.body)).not.toContain('db down');
  });
});

describe('GET /patient/users/fetchFamilyMembers/:family_id', () => {
  test('returns the members as a plain array', async () => {
    const rows = [{ member_id: 41, family_id: 9, name: 'Ravi', Gender_id: 1, Gender: 'Male', relation_id: 3, relation: 'Son', DOB: '2015-06-01T00:00:00.000Z', mobile_no: null }];
    mockDb.respond = familyDb({ rows });
    const res = await request(app).get('/patient/users/fetchFamilyMembers/9').set(patient());

    expect(res.body).toEqual(rows);
    expect(famCall().inputs.family_id).toBe('9');
  });

  test('DB failure → 500, generic message (S7)', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    const res = await request(app).get('/patient/users/fetchFamilyMembers/9').set(patient());
    expect(res.status).toBe(500);
    expect(res.body).toMatchObject({ success: false, message: 'Something went wrong. Please try again.' });
    expect(res.body.correlation_id).toBeTruthy();
    expect(JSON.stringify(res.body)).not.toContain('db down');
  });
});

describe('DELETE /patient/index/deleteFamilyMember/:member_id', () => {
  // B7: used to read `.Message` and answer 400 "Operation completed" every time.
  test('successful delete → 200', async () => {
    mockDb.respond = familyDb();
    const res = await request(app).delete('/patient/index/deleteFamilyMember/41').set(patient());

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, message: 'Member deleted successfully' });
    expect(famCall().inputs.member_id).toBe(41);
  });

  test('member used by appointments → 409 with the reason', async () => {
    mockDb.respond = familyDb({ referenced: true });
    const res = await request(app).delete('/patient/index/deleteFamilyMember/41').set(patient());
    expect(res.status).toBe(409);
    expect(res.body).toEqual({ success: false, message: 'Member is used in other records, cannot delete.' });
  });

  test('DB failure → 500', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    const res = await request(app).delete('/patient/index/deleteFamilyMember/41').set(patient());
    expect(res.status).toBe(500);
  });
});
