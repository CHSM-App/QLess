import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qless/core/database/local_database.dart';
import 'package:qless/core/database/offline_queue_store.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
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
}
