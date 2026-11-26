import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qless/core/database/local_database.dart';
import 'package:qless/core/database/offline_queue_store.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/domain/models/today_queue_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Replay rules for work saved offline (see OfflineQueueStore._flush).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = LocalDatabase.instance;
  final store = OfflineQueueStore(db);
  final ok = AppointmentResponseModel(success: true, message: 'ok');

  setUp(() => db.clearAll());

  Future<void> queueNext(int doctorId, int apptId) => store.enqueueOp(
      OfflineOperation.queueNext,
      AppointmentRequestModel(doctorId: doctorId, appointmentId: apptId));

  test('walk-ins survive flushPendingOps and are sent by flushPendingWalkIns', () async {
    await store.enqueueWalkInBook({'name': 'Asha', 'mobile_no': '9999999999', 'doctor_id': 1}, null);
    await queueNext(1, 10);

    final ops = <OfflineOperation>[];
    await store.flushPendingOps((op, _) async { ops.add(op); return ok; }, doctorId: 1);
    expect(ops, [OfflineOperation.queueNext]);
    expect(await store.pendingOpsCount(), 1); // the walk-in is still queued

    final bodies = <Map<String, dynamic>>[];
    await store.flushPendingWalkIns((b) async { bodies.add(b); return ok; }, doctorId: 1);
    expect(bodies.single['name'], 'Asha');
    expect(bodies.single.containsKey('_offlineTempApptId'), isFalse);
    expect(bodies.single['offline_queued_at'], isNotNull);
    expect(await store.pendingOpsCount(), 0);
  });

  test('network error stops the flush and keeps rows in order', () async {
    await queueNext(1, 10);
    await queueNext(1, 11);
    var calls = 0;
    final sent = await store.flushPendingOps((op, p) async {
      calls++;
      throw const SocketException('down');
    }, doctorId: 1);
    expect(sent, 0);
    expect(calls, 1);
    expect(await store.pendingOpsCount(), 2);
    expect(await store.failedCount(), 0);
  });

  test('server refusal parks the row as failed and later flushes skip it', () async {
    await queueNext(1, 10);
    await queueNext(1, 11);
    final sentIds = <int>[];
    await store.flushPendingOps((op, p) async {
      if (p['appointment_id'] == 10) {
        return AppointmentResponseModel(success: false, message: 'Doctor is on leave');
      }
      sentIds.add(p['appointment_id'] as int);
      return ok;
    }, doctorId: 1);
    expect(sentIds, [11]);
    expect(await store.failedCount(), 1);
    expect((await store.getFailedItems()).single['last_error'], 'Doctor is on leave');

    var calls = 0;
    await store.flushPendingOps((op, p) async { calls++; return ok; }, doctorId: 1);
    expect(calls, 0);
  });

  test('HTTP 4xx parks the row as failed', () async {
    await queueNext(1, 10);
    await store.flushPendingOps((op, p) async {
      final req = RequestOptions(path: '/x');
      throw DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: req, statusCode: 409, data: {'message': 'Conflict'}));
    }, doctorId: 1);
    expect(await store.pendingOpsCount(), 0);
    expect((await store.getFailedItems()).single['last_error'], 'Conflict');
  });

  test('a corrupt row does not block the rows after it', () async {
    await db.enqueuePendingOp(operation: 'notARealOp', payload: {}, doctorId: 1);
    await queueNext(1, 11);
    final sent = await store.flushPendingOps((op, p) async => ok, doctorId: 1);
    expect(sent, 1);
    expect(await store.failedCount(), 1);
  });

  test('rows of another doctor are never sent', () async {
    await queueNext(2, 20);
    await queueNext(1, 10);
    final sentIds = <int>[];
    await store.flushPendingOps((op, p) async {
      sentIds.add(p['appointment_id'] as int);
      return ok;
    }, doctorId: 1);
    expect(sentIds, [10]);

    await store.deletePendingForOtherDoctors(1);
    expect(await store.pendingOpsCount(), 0);
  });

  test('free text with quotes, backslashes and newlines round-trips', () async {
    await store.enqueueOp(
        OfflineOperation.queueNext,
        AppointmentRequestModel(doctorId: 1, appointmentId: 10, symptoms: 'fever "high"\nC:\\x'));
    Map<String, dynamic>? got;
    await store.flushPendingOps((op, p) async { got = p; return ok; }, doctorId: 1);
    expect(got!['symptoms'], 'fever "high"\nC:\\x');
  });

  group('sync fixes', () {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = '${now.year}-${two(now.month)}-${two(now.day)}';

    Future<int> walkIn() async {
      await store.enqueueWalkInBook(
          {'name': 'Asha', 'mobile_no': '9999999999', 'doctor_id': 1, 'appointment_date': today}, 1);
      return (await store.getCachedAppointments(1))
          .firstWhere((a) => (a.appointmentId ?? 0) < 0)
          .appointmentId!;
    }

    test('an action on an unsynced walk-in waits, and is parked once the walk-in fails', () async {
      final tempId = await walkIn();
      await queueNext(1, tempId);

      var calls = 0;
      await store.flushPendingOps((op, p) async { calls++; return ok; }, doctorId: 1);
      expect(calls, 0);
      expect(await store.failedCount(), 0);
      expect(await store.pendingOpsCount(), 2); // walk-in + its queueNext

      await store.flushPendingWalkIns(
          (b) async => AppointmentResponseModel(success: false, message: 'Doctor is on leave'),
          doctorId: 1);
      await store.flushPendingOps((op, p) async { calls++; return ok; }, doctorId: 1);
      expect(calls, 0);
      expect(await store.failedCount(), 2);
      expect((await store.getFailedItems()).map((r) => r['last_error']),
          contains('Walk-in booking did not sync'));
    });

    test('a 401 stops the pass without counting a retry', () async {
      await queueNext(1, 10);
      await queueNext(1, 11);
      var calls = 0;
      await store.flushPendingOps((op, p) async {
        calls++;
        final req = RequestOptions(path: '/x');
        throw DioException(
            requestOptions: req,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: req, statusCode: 401));
      }, doctorId: 1);
      expect(calls, 1);
      expect(await store.pendingOpsCount(), 2);
      expect((await db.getPendingOps(doctorId: 1)).map((r) => r['retry_count']), [0, 0]);
    });

    test('pending actions are laid back over freshly downloaded rows', () async {
      AppointmentList appt(int id, String status, int no) => AppointmentList(
          appointmentId: id, doctorId: 1, queueId: 5, bookingType: 1,
          status: status, appointmentDate: today, queueNumber: no);
      final server = [appt(10, 'in_progress', 1), appt(11, 'booked', 2), appt(12, 'booked', 3)];
      await store.cacheAppointments(server);
      await store.enqueueOp(OfflineOperation.queueNext,
          AppointmentRequestModel(doctorId: 1, appointmentId: 10, queueId: 5));

      // server rows land again before the sync — twice, as two fetches would
      for (var i = 0; i < 2; i++) {
        await store.cacheAppointments(server);
        await store.reapplyPendingOps(1);
      }
      final status = {for (final a in await store.getCachedAppointments(1)) a.appointmentId: a.status};
      expect(status, {10: 'completed', 11: 'in_progress', 12: 'booked'});
    });

    test('a medicine added offline gets its real id in queued prescriptions', () async {
      final tempId = await store.enqueueAddMedicine(
          Medicine(doctorId: 1, medicineName: 'Zincovit', medTypeId: 1));
      expect((await store.getCachedMedicines(1)).single.medicineId, tempId);
      await store.enqueuePrescription(PrescriptionModel(
          doctorId: 1, appointmentId: 10,
          medicines: [PrescriptionMedicineModel(medicineId: tempId)]));

      Map<String, dynamic>? sent;
      await store.flushPendingMedicines((b) async {
        sent = b;
        return {'success': 1, 'medicine_id': 99};
      }, doctorId: 1);
      expect(sent!['medicine_name'], 'Zincovit');
      expect(sent!.containsKey('_offlineTempMedId'), isFalse);
      expect((await store.getCachedMedicines(1)).single.medicineId, 99);

      PrescriptionModel? rx;
      await store.flushPendingPrescriptions((p) async {
        rx = p;
        return {'success': true};
      }, doctorId: 1);
      expect(rx!.medicines!.single.medicineId, 99);
    });
  });

  group('sessions from the schedule (offline start)', () {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final now = DateTime.now();
    final todayName = weekdays[now.weekday - 1];
    final otherDay = weekdays[now.weekday % 7];
    String two(int n) => n.toString().padLeft(2, '0');
    final today = '${now.year}-${two(now.month)}-${two(now.day)}';

    Map<String, dynamic> slot(int id, String start, String end, int mode) =>
        {'slot_id': id, 'start_time': start, 'end_time': end, 'booking_mode': mode};

    Future<void> cacheSchedule(List<Map<String, dynamic>> days) =>
        store.cacheJson('schedule:1:', {'doctor_id': 1, 'schedule': days});

    test('adds a -slot_id session for each of today\'s open queue slots', () async {
      await cacheSchedule([
        {'day': todayName, 'is_enabled': 1, 'slots': [
          slot(7, '00:00', '23:59', 1),  // queue
          slot(8, '00:00', '23:59', 3),  // queue + slots
          slot(9, '00:00', '23:59', 2),  // slots only — no queue
          slot(10, '00:00', '00:00', 1), // already over
        ]},
        {'day': otherDay, 'is_enabled': 1, 'slots': [slot(11, '00:00', '23:59', 1)]},
      ]);
      await store.ensureScheduledSessions(1);

      final sessions = await store.getCachedQueues(1);
      expect(sessions.map((q) => q.queueId).toSet(), {-7, -8});
      final s7 = sessions.firstWhere((q) => q.queueId == -7);
      expect(s7.slotId, 7);
      expect(s7.queueStatus, 0);
      expect(s7.queueDate, today);
      expect(s7.startTime, '1970-01-01T00:00:00.000Z');

      // running it again does not duplicate anything
      await store.ensureScheduledSessions(1);
      expect((await store.getCachedQueues(1)).length, 2);
    });

    test('a downloaded slot keeps its real session, and a real one replaces a stand-in', () async {
      await cacheSchedule([
        {'day': todayName, 'is_enabled': 1, 'slots': [slot(7, '00:00', '23:59', 1), slot(8, '00:00', '23:59', 1)]},
      ]);
      await store.cacheQueues([TodayQueueModel(queueId: 70, doctorId: 1, slotId: 7, queueDate: '${today}T00:00:00.000Z')]);
      await store.ensureScheduledSessions(1);
      expect((await store.getCachedQueues(1)).map((q) => q.queueId).toSet(), {70, -8});

      await store.cacheQueues([TodayQueueModel(queueId: 80, doctorId: 1, slotId: 8, queueDate: '${today}T00:00:00.000Z')]);
      expect((await store.getCachedQueues(1)).map((q) => q.queueId).toSet(), {70, 80});
    });

    test('nothing is added on a leave day or a disabled day', () async {
      await cacheSchedule([
        {'day': todayName, 'is_enabled': 1, 'slots': [slot(7, '00:00', '23:59', 1)]},
      ]);
      await store.cacheJson('leaves:1', [{'leave_id': 1, 'from_date': today, 'to_date': today}]);
      await store.ensureScheduledSessions(1);
      expect(await store.getCachedQueues(1), isEmpty);

      await store.cacheJson('leaves:1', []);
      await cacheSchedule([
        {'day': todayName, 'is_enabled': 0, 'slots': [slot(7, '00:00', '23:59', 1)]},
      ]);
      await store.ensureScheduledSessions(1);
      expect(await store.getCachedQueues(1), isEmpty);
    });
  });
}
