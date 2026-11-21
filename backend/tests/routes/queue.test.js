const request = require('supertest');
const { mockDb } = require('../helpers/db');
const { authHeader } = require('../helpers/auth');
const fcm = require('../../src/fcm');
const app = require('../../src/server');

// Capture what the routes broadcast over Socket.IO.
const emitted = [];
app.set('io', { to: (room) => ({ emit: (event, payload) => emitted.push({ room, event, payload }) }) });

const send = () => fcm.messaging().send;
// a token for doctor 2 — the doctor whose queue these tests drive
const post = (url, body) => request(app).post('/doctor/insert' + url).set(authHeader({ uid: 2 })).send(body);

// sp_appointment answers per operation; the helpers around it (inbox lookup,
// current-serving query) answer with fixed rows.
function queueDb(spRows) {
  return ({ kind, target, inputs }) => {
    if (target === 'sp_appointment') return spRows[inputs.operation] || [];
    if (kind === 'query' && target.includes('FROM patients') && target.includes('token_hash')) return [{ patient_id: 9 }];
    if (kind === 'query' && target.includes('MAX(a.queue_number) AS current_serving')) return [{ current_serving: 4 }];
    return [];
  };
}

beforeEach(() => {
  mockDb.reset();
  emitted.length = 0;
  send().mockClear();
});

describe('POST /appointment/queueNext', () => {
  test('400 without doctor_id or appointment_id', async () => {
    expect((await post('/appointment/queueNext', { appointment_id: 1 })).status).toBe(400);
    expect((await post('/appointment/queueNext', { doctor_id: 2 })).status).toBe(400);
    expect(mockDb.callsTo('sp_appointment')).toHaveLength(0);
  });

  test('moves the queue, notifies the next patient and broadcasts current serving', async () => {
    mockDb.respond = queueDb({ NEXT_SESSION: [{ success: 1, token: 'fcm-next', message: 'ok' }] });
    const res = await post('/appointment/queueNext', { doctor_id: 2, appointment_id: 11, clinic_id: 3 });

    expect(res.body).toEqual({ success: true, message: 'ok' });
    expect(mockDb.callsTo('sp_appointment', 'NEXT_SESSION')[0].inputs)
      .toMatchObject({ doctor_id: 2, appointment_id: 11, clinic_id: 3 });
    expect(send()).toHaveBeenCalledWith(expect.objectContaining({
      token: 'fcm-next',
      notification: expect.objectContaining({ title: 'Your Turn Now' }),
    }));
    expect(mockDb.callsTo('sp_notification', 'INSERT')[0].inputs).toMatchObject({ patient_id: 9, type: 'appointment' });
    expect(emitted).toContainEqual({
      room: 'clinic_2', event: 'queue_update',
      payload: expect.objectContaining({ event: 'next', doctor_id: 2, current_serving: 4 }),
    });
  });

  test('a stale offline replay updates the queue but sends no push', async () => {
    mockDb.respond = queueDb({ NEXT_SESSION: [{ success: 1, token: 'fcm-next' }] });
    const hourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const res = await post('/appointment/queueNext', { doctor_id: 2, appointment_id: 11, offline_queued_at: hourAgo });

    expect(res.body.success).toBe(true);
    expect(send()).not.toHaveBeenCalled();
    expect(emitted.map((e) => e.payload.event)).toContain('next');
  });

  test('SP refusal is passed through without notifying anyone', async () => {
    mockDb.respond = queueDb({ NEXT_SESSION: [{ success: 0, message: 'Queue not started' }] });
    const res = await post('/appointment/queueNext', { doctor_id: 2, appointment_id: 11 });

    expect(res.body).toEqual({ success: false, message: 'Queue not started' });
    expect(send()).not.toHaveBeenCalled();
    expect(emitted).toHaveLength(0);
  });

  test('a push failure does not fail the queue move', async () => {
    mockDb.respond = queueDb({ NEXT_SESSION: [{ success: 1, token: 'dead-token' }] });
    send().mockRejectedValueOnce(Object.assign(new Error('unregistered'), { code: 'messaging/registration-token-not-registered' }));
    const res = await post('/appointment/queueNext', { doctor_id: 2, appointment_id: 11 });
    expect(res.body.success).toBe(true);
  });

  test('500 when the database fails', async () => {
    mockDb.respond = () => { throw new Error('db down'); };
    const res = await post('/appointment/queueNext', { doctor_id: 2, appointment_id: 11 });
    expect(res.status).toBe(500);
  });
});

describe('POST /appointment/queueSkip', () => {
  test('notifies only the skipped patient and broadcasts skip', async () => {
    mockDb.respond = queueDb({ SKIP_SESSION: [{ success: 1, token: 'fcm-skipped' }] });
    const res = await post('/appointment/queueSkip', { doctor_id: 2, appointment_id: 12, is_next: 1 });

    expect(res.body.success).toBe(true);
    expect(mockDb.callsTo('sp_appointment', 'SKIP_SESSION')[0].inputs).toMatchObject({ is_next: 1 });
    expect(send()).toHaveBeenCalledWith(expect.objectContaining({
      token: 'fcm-skipped',
      data: { type: 'appointment', appointment_id: '12' },
    }));
    expect(emitted.map((e) => e.payload.event)).toContain('skip');
  });
});

describe('POST /appointment/queueRecall', () => {
  test('400 without appointment_id', async () => {
    expect((await post('/appointment/queueRecall', { doctor_id: 2 })).status).toBe(400);
  });

  test('broadcasts recall only when the SP succeeded', async () => {
    mockDb.respond = queueDb({ RECALL_SESSION: [{ success: 1 }] });
    const ok = await post('/appointment/queueRecall', { doctor_id: 2, appointment_id: 12 });
    expect(ok.body.success).toBe(true);
    expect(emitted.map((e) => e.payload.event)).toEqual(['recall']);

    emitted.length = 0;
    mockDb.respond = queueDb({ RECALL_SESSION: [{ success: 0, message: 'nope' }] });
    const refused = await post('/appointment/queueRecall', { doctor_id: 2, appointment_id: 12 });
    expect(refused.body).toEqual({ success: false, message: 'nope' });
    expect(emitted).toHaveLength(0);
  });
});

describe('POST /walkInBook', () => {
  const walkIn = { name: ' Asha ', mobile_no: '9000011111', doctor_id: 2, appointment_date: '2026-11-20', clinic_id: 3 };

  function walkInDb({ blocked = 0, booked = 1, duplicate = null, idle = null } = {}) {
    return ({ kind, target, inputs }) => {
      if (kind === 'query' && target.includes('JOIN doctor_queue dq')) return idle ? [idle] : [];
      if (kind === 'query' && target.includes('FROM appointments a')) return duplicate ? [duplicate] : [];
      if (target === 'sp_appointment' && inputs.operation === 'START_SESSION') return [{ success: 1 }];
      if (target === 'sp_patients' && inputs.operation === 'Insert') return [{ patient_id: 41 }];
      if (kind === 'query' && /INSERT INTO dbo\.family_members/.test(target)) return [{ member_id: 51 }];
      if (target === 'sp_doctor_leave' && inputs.operation === 'IS_BLOCKED') return [{ blocked }];
      if (target === 'sp_appointment' && inputs.operation === 'BOOK') return [{ success: booked, message: booked ? 'Booked' : 'Full' }];
      return [];
    };
  }

  test('400 when a required field is missing', async () => {
    const res = await post('/walkInBook', { ...walkIn, name: '' });
    expect(res.status).toBe(400);
  });

  test('new walk-in: creates a patient profile, books, broadcasts', async () => {
    mockDb.respond = walkInDb();
    const res = await post('/walkInBook', walkIn);

    expect(res.body).toEqual({ success: true, message: 'Booked', patient_id: 41, started_appointment_id: null });
    expect(mockDb.callsTo('sp_appointment', 'START_SESSION')).toHaveLength(0);
    expect(mockDb.callsTo('sp_patients', 'Insert')[0].inputs.name).toBe('Asha');
    expect(mockDb.callsTo('sp_appointment', 'BOOK')[0].inputs).toMatchObject({ patient_id: 41, user_type: 1, clinic_id: 3 });
    expect(emitted.map((e) => e.payload.event)).toEqual(['booked']);
  });

  test('idle running queue: starts the walk-in straight away', async () => {
    mockDb.respond = walkInDb({ idle: { appointment_id: 90 } });
    const res = await post('/walkInBook', walkIn);

    expect(res.body.started_appointment_id).toBe(90);
    expect(mockDb.callsTo('sp_appointment', 'START_SESSION')[0].inputs.appointment_id).toBe(90);
    expect(emitted.map((e) => e.payload.event)).toEqual(['booked', 'session_started']);
  });

  test('family member walk-in books under the new member id', async () => {
    mockDb.respond = walkInDb();
    const res = await post('/walkInBook', { ...walkIn, family_id: 8, user_type: 2 });

    expect(res.body.patient_id).toBe(51);
    expect(mockDb.callsTo('sp_patients', 'Insert')).toHaveLength(0);
    expect(mockDb.callsTo('sp_appointment', 'BOOK')[0].inputs).toMatchObject({ patient_id: 51, user_type: 2 });
  });

  test('refuses when the doctor is on leave that day', async () => {
    mockDb.respond = walkInDb({ blocked: 1 });
    const res = await post('/walkInBook', walkIn);

    expect(res.body.success).toBe(false);
    expect(mockDb.callsTo('sp_appointment', 'BOOK')).toHaveLength(0);
  });

  test('offline replay of an already-booked walk-in does not book twice', async () => {
    mockDb.respond = walkInDb({ duplicate: { appointment_id: 77, patient_id: 41 } });
    const res = await post('/walkInBook', { ...walkIn, offline_queued_at: new Date().toISOString() });

    expect(res.body).toEqual({ success: true, message: 'Walk-in already booked', patient_id: 41 });
    expect(mockDb.callsTo('sp_patients', 'Insert')).toHaveLength(0);
    expect(mockDb.callsTo('sp_appointment', 'BOOK')).toHaveLength(0);
  });
});
