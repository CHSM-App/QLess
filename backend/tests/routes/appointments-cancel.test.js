const request = require('supertest');
const { mockDb } = require('../helpers/db');
const { authHeader, ROLE } = require('../helpers/auth');
const appointmentsSql = require('../../src/queries/appointments');
const app = require('../../src/server');

const me = () => authHeader({ role_id: ROLE.PATIENT, uid: 9 });

beforeEach(() => mockDb.reset());

// B10: /appointment/cancel sent operation 'CANCEL', which the appointment SQL
// never had, so nothing was cancelled while the app was told it was.
test('B10: /appointment/cancel runs CANCEL_APPOINTMENT', async () => {
  mockDb.respond = () => [{ success: 1, message: 'Appointment cancelled' }];
  const res = await request(app).post('/patient/insert/appointment/cancel').set(me()).send({ appointment_id: 77 });

  expect(res.body).toEqual({ success: true, message: 'Appointment cancelled' });
  expect(mockDb.callsTo('sp_appointment', 'CANCEL_APPOINTMENT')[0].inputs.appointment_id).toBe(77);
  expect(mockDb.callsTo('sp_appointment', 'CANCEL')).toHaveLength(0);
});

// B11: leave/slot cancels called an operation that did not exist; the status
// stayed 'cancelled' and the app showed a self-cancel instead of "by doctor".
test('B11: MARK_APPT_DOCTOR_CANCELLED exists and only touches cancelled rows', () => {
  const text = appointmentsSql.ops.MARK_APPT_DOCTOR_CANCELLED;
  expect(text).toMatch(/SET status = 'CancleD'/);
  expect(text).toMatch(/WHERE appointment_id = @appointment_id AND status IN \('cancelled', 'cancled'\)/);
});
