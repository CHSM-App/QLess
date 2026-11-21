const request = require('supertest');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const fcm = require('../../src/fcm');
const app = require('../../src/server');

// The rest of the live queue (queue.test.js covers next / skip / recall / walk-in).
const emitted = [];
app.set('io', { to: () => ({ emit: (e, p) => emitted.push(p.event) }) });
const post = (url, body, role = ROLE.DOCTOR) => request(app).post('/doctor/insert' + url).set(authHeader({ role_id: role, uid: 1 })).send(body);
const op = (name) => mockDb.callsTo('sp_appointment', name);
const flush = () => new Promise((r) => setImmediate(r));

beforeEach(() => {
  mockDb.reset();
  emitted.length = 0;
  fcm.messaging().send.mockClear();
  fcm.messaging().sendEachForMulticast.mockClear();
});

describe('queueStart', () => {
  test('400 without doctor_id', async () => {
    expect((await post('/appointment/queueStart', { queue_id: 1 })).status).toBe(400);
  });

  test('status row + token rows in separate recordsets → everyone waiting gets "Doctor Arrived"', async () => {
    mockDb.respond = ({ target, inputs }) => {
      if (target === 'sp_appointment' && inputs.operation === 'QUEUE_START') {
        const sets = [[{ success: 1 }], [{ token: 'a' }, { token: 'b' }, { token: '' }]];
        return { recordset: sets[0], recordsets: sets, rowsAffected: [1] };
      }
      if (inputs && inputs.operation === 'APPT_CONTEXT_QUEUE') return [{ doctor_name: 'Asha' }];
      return [];
    };
    const res = await post('/appointment/queueStart', { doctor_id: 1, queue_id: 3 });

    expect(res.body).toMatchObject({ success: true, total_tokens: 2 });
    const msg = fcm.messaging().sendEachForMulticast.mock.calls[0][0];
    expect(msg.tokens).toEqual(['a', 'b']);
    expect(msg.notification.body).toBe('Dr. Asha has started the queue. Please be ready.');
    expect(emitted).toContain('queue_started');
  });

  test('nobody waiting → started, no push', async () => {
    mockDb.respond = () => [{ success: 1 }];
    const res = await post('/appointment/queueStart', { doctor_id: 1, queue_id: 3 });
    expect(res.body.message).toBe('Queue started, no patients to notify');
    expect(fcm.messaging().sendEachForMulticast).not.toHaveBeenCalled();
  });

  // B12: the queue is already started when the push goes out; a Firebase
  // failure used to turn that into a 500.
  test('Firebase failure after the start still answers success, 0 delivered (B12)', async () => {
    mockDb.respond = ({ inputs }) => (inputs.operation === 'QUEUE_START' ? [{ success: 1 }, { token: 'a' }] : []);
    fcm.messaging().sendEachForMulticast.mockRejectedValueOnce(new Error('firebase down'));
    const res = await post('/appointment/queueStart', { doctor_id: 1, queue_id: 3 });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ success: true, total_tokens: 1 });
    expect(op('QUEUE_START')).toHaveLength(1);
    await flush(); // the background push failed quietly
  });

  test('queuePause: Firebase failure still answers success (B12)', async () => {
    mockDb.respond = ({ inputs }) => (inputs.operation === 'QUEUE_PAUSE'
      ? { recordset: [{ success: 1 }], recordsets: [[{ success: 1 }], [{ token: 'a' }]], rowsAffected: [1] } : []);
    fcm.messaging().sendEachForMulticast.mockRejectedValueOnce(new Error('firebase down'));
    const res = await post('/appointment/queuePause', { doctor_id: 1, queue_id: 3 });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ success: true, total_tokens: 1 });
    await flush();
  });

  // A1: the doctor is answered before the push; N tokens → one inbox batch + one multicast.
  test('answers before the push, then one inbox batch and one multicast (A1)', async () => {
    let releasePush;
    fcm.messaging().sendEachForMulticast.mockImplementationOnce(() => new Promise((r) => { releasePush = () => r({ successCount: 3, failureCount: 0 }); }));
    mockDb.respond = ({ inputs }) => (inputs && inputs.operation === 'QUEUE_START' ? [{ success: 1 }, { token: 'a' }, { token: 'b' }, { token: 'c' }] : []);
    const res = await post('/appointment/queueStart', { doctor_id: 1, queue_id: 3 });
    expect(res.body).toMatchObject({ success: true, total_tokens: 3 }); // answered while the push is still pending
    await flush();
    expect(fcm.messaging().sendEachForMulticast).toHaveBeenCalledTimes(1);
    releasePush();
    const inbox = mockDb.calls.filter((c) => /OPENJSON\(@tokens\)/.test(c.target));
    expect(inbox).toHaveLength(1);
    expect(JSON.parse(inbox[0].inputs.tokens)).toEqual(['a', 'b', 'c']);
    expect(mockDb.calls.filter((c) => /token_hash = CONVERT/.test(c.target) && !/OPENJSON/.test(c.target))).toHaveLength(0);
  });

  test('inbox insert failure still sends the push (A1)', async () => {
    mockDb.respond = ({ target, inputs }) => {
      if (/OPENJSON/.test(target)) throw new Error('db hiccup');
      return inputs && inputs.operation === 'QUEUE_START' ? [{ success: 1 }, { token: 'a' }] : [];
    };
    expect((await post('/appointment/queueStart', { doctor_id: 1, queue_id: 3 })).status).toBe(200);
    await flush();
    expect(fcm.messaging().sendEachForMulticast).toHaveBeenCalledTimes(1);
  });
});

describe('pause / stop / booking window', () => {
  test('queuePause: refusal passed through, no push', async () => {
    mockDb.respond = () => ({ recordset: [{ success: 0, message: 'Queue not running' }], recordsets: [[{ success: 0, message: 'Queue not running' }]], rowsAffected: [1] });
    const res = await post('/appointment/queuePause', { doctor_id: 1, queue_id: 3 });
    expect(res.body).toEqual({ success: false, message: 'Queue not running' });
    expect(fcm.messaging().sendEachForMulticast).not.toHaveBeenCalled();
  });

  test('queuePause: success notifies the waiting tokens', async () => {
    mockDb.respond = ({ inputs }) => (inputs.operation === 'QUEUE_PAUSE'
      ? { recordset: [{ success: 1 }], recordsets: [[{ success: 1 }], [{ token: 'a' }]], rowsAffected: [1] } : []);
    const res = await post('/appointment/queuePause', { doctor_id: 1, queue_id: 3 });
    expect(res.status).toBe(200);
    expect(emitted).toContain('queue_paused');
  });

  test('emergency pause uses the queue id from the URL', async () => {
    mockDb.respond = () => [{ success: 1, doctor_id: 1 }];
    await post('/appointment/queuePauseEmergency/3', {});
    expect(op('QUEUE_PAUSE_EMERGENCY')[0].inputs.queue_id).toBe('3');
  });

  test('queueStop passes queue + doctor and broadcasts', async () => {
    mockDb.respond = () => [{ success: 1 }];
    const res = await post('/appointment/queueStop', { doctor_id: 1, queue_id: 3 });
    expect(res.status).toBe(200);
    expect(op('QUEUE_STOP')[0].inputs).toMatchObject({ doctor_id: 1, queue_id: 3 });
    expect(emitted).toContain('queue_stopped');
  });

  test('stopBooking: 400 without doctor_id', async () => {
    expect((await post('/appointment/stopBooking', { queue_id: 3, booking_closed: 1 })).status).toBe(400);
  });
});

describe('sessions and doctor cancel', () => {
  test('startSession: 400 without ids; success broadcasts current serving', async () => {
    expect((await post('/appointment/startSession', { doctor_id: 1 })).status).toBe(400);
    mockDb.respond = ({ kind, target }) => (kind === 'query' && /current_serving/.test(target) ? [{ current_serving: 2 }] : [{ success: 1 }]);
    const res = await post('/appointment/startSession', { doctor_id: 1, appointment_id: 8 });
    expect(res.body.success).toBe(true);
    expect(emitted).toContain('session_started');
  });

  test('endSession passes doctor, appointment and clinic', async () => {
    mockDb.respond = () => [{ success: 1 }];
    await post('/appointment/endSession', { doctor_id: 1, appointment_id: 8, clinic_id: 'CL001' });
    expect(op('END_SESSION')[0].inputs).toMatchObject({ doctor_id: 1, appointment_id: 8, clinic_id: 'CL001' });
    expect(emitted).toContain('session_ended');
  });

  test('cancelByDoctor cancels and broadcasts', async () => {
    mockDb.respond = () => [{ success: 1, token: 'p-token' }];
    const res = await post('/appointment/cancelByDoctor', { doctor_id: 1, appointment_id: 8 });
    expect(res.status).toBe(200);
    expect(op('CANCEL_BY_DOCTOR')[0].inputs).toMatchObject({ doctor_id: 1, appointment_id: 8 });
    expect(emitted).toContain('cancel');
  });

  test('receptionists may run the queue too', async () => {
    mockDb.respond = () => [{ success: 1 }];
    expect((await post('/appointment/queueStop', { doctor_id: 1, queue_id: 3 }, ROLE.RECEPTIONIST)).status).toBe(200);
  });
});

// B13 (fixed): RECALL_SESSION needs @doctor_id to find today's running queue;
// without it every queue recall failed on the real database.
test('queueRecall passes doctor_id to the database', async () => {
  mockDb.respond = () => [{ success: 1 }];
  await post('/appointment/queueRecall', { doctor_id: 1, appointment_id: 8 });
  expect(op('RECALL_SESSION')[0].inputs).toEqual({ operation: 'RECALL_SESSION', appointment_id: 8, doctor_id: 1 });
});
