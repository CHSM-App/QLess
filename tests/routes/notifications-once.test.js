const { mockDb } = require('../helpers/db');
const fcm = require('../../src/fcm');
const refreshTokensSql = require('../../src/queries/refreshTokens');
const {
  insertNotificationOnce,
  insertNotificationForToken,
  sendPositionNotifications,
} = require('../../src/routes/doctor/insert/shared');

beforeEach(() => { mockDb.reset(); fcm.messaging().send.mockClear(); });

describe('insertNotificationOnce (D5)', () => {
  test('stored → true; already there → false', async () => {
    mockDb.respond = () => [{ inserted: 1 }];
    expect(await insertNotificationOnce(9, 'T', 'B', 'queue', '5:queue_next')).toBe(true);
    expect(mockDb.callsTo('sp_notification', 'INSERT_ONCE')[0].inputs)
      .toMatchObject({ patient_id: 9, type: 'queue', ref_id: '5:queue_next' });

    mockDb.respond = () => [{ inserted: 0 }];
    expect(await insertNotificationOnce(9, 'T', 'B', 'queue', '5:queue_next')).toBe(false);
  });

  test('DB error → false (no duplicate push)', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    expect(await insertNotificationOnce(9, 'T', 'B', 'queue', '5:queue_next')).toBe(false);
  });

  test('the SQL checks and inserts in one statement', () => {
    const text = require('../../src/queries/notifications').ops.INSERT_ONCE;
    expect(text).toMatch(/INSERT INTO notifications[\s\S]*WHERE NOT EXISTS[\s\S]*UPDLOCK, HOLDLOCK/);
  });
});

describe('sendPositionNotifications', () => {
  const rows = [
    { appointment_id: 21, position: 1, token: 'tk1', patient_id: 4, doctor_name: 'Asha' },
    { appointment_id: 22, position: 2, token: 'tk2', patient_id: 5, doctor_name: 'Asha' },
  ];

  // B17: the query filtered on status 'waiting', which nothing ever writes.
  test("B17: picks the waiting patients by status 'booked'", async () => {
    mockDb.respond = ({ kind }) => (kind === 'query' ? rows : [{ inserted: 1 }]);
    await sendPositionNotifications(1, 21);
    const q = mockDb.calls.find((c) => c.kind === 'query').target;
    expect(q).toMatch(/a\.status = 'booked'/);
    expect(q).not.toMatch(/'waiting'/);
    expect(fcm.messaging().send).toHaveBeenCalledTimes(2);
  });

  test('a stage already sent is not pushed again', async () => {
    mockDb.respond = ({ kind, inputs }) => (kind === 'query' ? rows
      : [{ inserted: inputs.ref_id === '21:queue_next' ? 0 : 1 }]);
    await sendPositionNotifications(1, 21);
    expect(fcm.messaging().send).toHaveBeenCalledTimes(1);
    expect(fcm.messaging().send.mock.calls[0][0].token).toBe('tk2');
  });
});

test('D3: token owner is found through the indexed token_hash', async () => {
  mockDb.respond = ({ kind }) => (kind === 'query' ? [{ patient_id: 4 }] : [{ success: 1 }]);
  await insertNotificationForToken('tk1', 'T', 'B', 'queue', 1);
  expect(mockDb.calls.find((c) => c.kind === 'query').target).toMatch(/WHERE token_hash = CONVERT\(CHAR\(64\), HASHBYTES\('SHA2_256', @token\), 2\) AND token = @token/);
  expect(mockDb.callsTo('sp_notification', 'INSERT')[0].inputs.patient_id).toBe(4);
});

test('D7: a new session takes its id from the sequence, no MAX(id) lock', () => {
  expect(refreshTokensSql.ops.insert).not.toMatch(/MAX\(id\)/);
  expect(refreshTokensSql.ops.insert).toMatch(/OUTPUT inserted\.id/);
});
