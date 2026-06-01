import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:qless/core/database/local_database.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/today_queue_model.dart';

/// Possible offline queue operations that can be queued for later sync.
enum OfflineOperation {
  queueStart,
  queuePause,
  queueStop,
  queueNext,
  queueSkip,
  queueRecall,
  queuePauseEmergency,
}

extension OfflineOperationX on OfflineOperation {
  String get name {
    switch (this) {
      case OfflineOperation.queueStart:          return 'queueStart';
      case OfflineOperation.queuePause:          return 'queuePause';
      case OfflineOperation.queueStop:           return 'queueStop';
      case OfflineOperation.queueNext:           return 'queueNext';
      case OfflineOperation.queueSkip:           return 'queueSkip';
      case OfflineOperation.queueRecall:         return 'queueRecall';
      case OfflineOperation.queuePauseEmergency: return 'queuePauseEmergency';
    }
  }

  static OfflineOperation fromString(String s) {
    switch (s) {
      case 'queueStart':          return OfflineOperation.queueStart;
      case 'queuePause':          return OfflineOperation.queuePause;
      case 'queueStop':           return OfflineOperation.queueStop;
      case 'queueNext':           return OfflineOperation.queueNext;
      case 'queueSkip':           return OfflineOperation.queueSkip;
      case 'queueRecall':         return OfflineOperation.queueRecall;
      case 'queuePauseEmergency': return OfflineOperation.queuePauseEmergency;
      default: throw ArgumentError('Unknown offline operation: $s');
    }
  }
}

/// A pending operation row deserialized from SQLite.
class PendingOperation {
  final int id;
  final OfflineOperation operation;
  final Map<String, dynamic> payload;
  final int? doctorId;
  final int? queueId;
  final int? appointmentId;
  final int retryCount;

  const PendingOperation({
    required this.id,
    required this.operation,
    required this.payload,
    this.doctorId,
    this.queueId,
    this.appointmentId,
    this.retryCount = 0,
  });

  factory PendingOperation.fromRow(Map<String, dynamic> row) {
    return PendingOperation(
      id:            row['id'] as int,
      operation:     OfflineOperationX.fromString(row['operation'] as String),
      payload:       jsonDecode(row['payload_json'] as String) as Map<String, dynamic>,
      doctorId:      row['doctor_id'] as int?,
      queueId:       row['queue_id'] as int?,
      appointmentId: row['appointment_id'] as int?,
      retryCount:    row['retry_count'] as int? ?? 0,
    );
  }
}

/// High-level service that sits between the ViewModel and SQLite.
///
/// Responsibilities:
///  1. Cache appointments + queues fetched from the server.
///  2. Enqueue offline operations when the device is offline.
///  3. Apply optimistic local mutations so the UI updates immediately.
///  4. Expose [flushPendingOps] for the sync controller to call on reconnect.
class OfflineQueueStore {
  final LocalDatabase _db;

  OfflineQueueStore(this._db);

  // ── Cache writes ─────────────────────────────────────────────────────────────

  Future<void> cacheQueues(List<TodayQueueModel> queues) async {
    final rows = queues.map((q) => q.toJson()).toList();
    await _db.upsertQueues(rows);
  }

  Future<void> cacheAppointments(List<AppointmentList> appointments) async {
    final rows = appointments.map((a) => _appointmentToRow(a)).toList();
    await _db.upsertAppointments(rows);
  }

  // ── Cache reads ──────────────────────────────────────────────────────────────

  Future<List<TodayQueueModel>> getCachedQueues(int doctorId) async {
    final rows = await _db.getQueuesForDoctor(doctorId);
    return rows.map(TodayQueueModel.fromJson).toList();
  }

  Future<List<AppointmentList>> getCachedAppointments(int doctorId) async {
    final rows = await _db.getAppointmentsForDoctor(doctorId);
    return rows.map(_rowToAppointment).toList();
  }

  // ── Optimistic local mutations ───────────────────────────────────────────────

  /// Apply an offline queue state change locally so the UI updates without
  /// waiting for the server. Maps operation → SQLite queue_status value.
  Future<void> applyOfflineQueueOp(
    OfflineOperation op,
    int? queueId,
    int? appointmentId,
  ) async {
    switch (op) {
      case OfflineOperation.queueStart:
        if (queueId != null) await _db.updateQueueStatus(queueId, 1);
        break;
      case OfflineOperation.queuePause:
      case OfflineOperation.queuePauseEmergency:
        if (queueId != null) await _db.updateQueueStatus(queueId, 2);
        break;
      case OfflineOperation.queueStop:
        if (queueId != null) await _db.updateQueueStatus(queueId, 3);
        break;
      case OfflineOperation.queueNext:
        if (appointmentId != null) {
          await _db.updateAppointmentStatus(appointmentId, 'completed');
        }
        break;
      case OfflineOperation.queueSkip:
        if (appointmentId != null) {
          await _db.updateAppointmentStatus(appointmentId, 'skipped');
        }
        break;
      case OfflineOperation.queueRecall:
        if (appointmentId != null) {
          await _db.updateAppointmentStatus(appointmentId, 'pending');
        }
        break;
    }
  }

  // ── Pending-op queue ─────────────────────────────────────────────────────────

  Future<void> enqueueOp(
    OfflineOperation op,
    AppointmentRequestModel request, {
    int? queueId,
  }) async {
    await _db.enqueuePendingOp(
      operation:     op.name,
      payload:       request.toJson(),
      doctorId:      request.doctorId,
      queueId:       queueId ?? request.queueId,
      appointmentId: request.appointmentId,
    );
    debugPrint('[OfflineQueueStore] Enqueued offline op: ${op.name}');
  }

  Future<void> enqueueEmergencyPause(int queueId, int doctorId) async {
    await _db.enqueuePendingOp(
      operation: OfflineOperation.queuePauseEmergency.name,
      payload:   {'queue_id': queueId, 'doctor_id': doctorId},
      doctorId:  doctorId,
      queueId:   queueId,
    );
    debugPrint('[OfflineQueueStore] Enqueued offline emergency pause: $queueId');
  }

  Future<List<PendingOperation>> getPendingOps() async {
    final rows = await _db.getPendingOps();
    return rows.map(PendingOperation.fromRow).toList();
  }

  Future<int> pendingOpsCount() => _db.pendingOpsCount();

  Future<void> deletePendingOp(int id) => _db.deletePendingOp(id);

  Future<void> incrementRetry(int id) => _db.incrementRetry(id);

  /// Flush all pending offline operations by executing them against the API.
  ///
  /// [executor] is a callback from the ViewModel that knows how to call each
  /// operation. Returns the number of successfully flushed ops.
  Future<int> flushPendingOps(
    Future<AppointmentResponseModel> Function(
      OfflineOperation op,
      Map<String, dynamic> payload,
    ) executor,
  ) async {
    final ops = await getPendingOps();
    if (ops.isEmpty) return 0;

    int flushed = 0;
    for (final op in ops) {
      try {
        await executor(op.operation, op.payload);
        await deletePendingOp(op.id);
        flushed++;
        debugPrint('[OfflineQueueStore] Flushed op ${op.id} (${op.operation.name})');
      } catch (e) {
        await incrementRetry(op.id);
        debugPrint('[OfflineQueueStore] Failed op ${op.id}: $e');
      }
    }
    return flushed;
  }

  // ── Serialization helpers ────────────────────────────────────────────────────

  Map<String, dynamic> _appointmentToRow(AppointmentList a) => {
        'appointment_id':         a.appointmentId,
        'patient_id':             a.patientId,
        'queue_id':               a.queueId,
        'slot_id':                a.slotId,
        'doctor_id':              a.doctorId,
        'family_id':              a.familyId,
        'patient_name':           a.patientName,
        'mobile':                 a.mobile,
        'gender':                 a.gender,
        'DOB':                    a.dob,
        'symptoms':               a.symptoms,
        'queue_number':           a.queueNumber,
        'booking_type':           a.bookingType,
        'start_time':             a.startTime,
        'end_time':               a.endTime,
        'status':                 a.status,
        'booking_for':            a.bookingFor,
        'user_type':              a.userType,
        'queue_status':           a.queueStatus,
        'my_queue_number':        a.myQueueNumber,
        'patients_ahead':         a.patientsAhead,
        'estimated_arrival_time': a.estimatedArrivalTime,
        'queue_state':            a.queueState,
        'queue_started':          (a.queueStarted ?? false) ? 1 : 0,
        'is_my_turn':             (a.isMyTurn ?? false) ? 1 : 0,
        'cancelled_by':           a.cancelledBy,
        'total_queue':            a.totalQueue,
        'current_serving':        a.currentServing,
        'is_reviewed':            (a.isReviewed ?? false) ? 1 : 0,
        'appointment_date':       a.appointmentDate,
        'doctor_name':            a.doctorName,
        'specialization':         a.specialization,
        'clinic_id':              a.clinicId,
        'clinic_name':            a.clinicName,
        'clinic_address':         a.clinicAddress,
        'clinic_contact':         a.clinicContact,
        'latitude':               a.latitude,
        'longitude':              a.longitude,
      };

  /// Reconstruct an [AppointmentList] from a SQLite row by remapping column
  /// names back to the JSON keys that [AppointmentList.fromJson] expects, then
  /// delegating to the generated factory. This avoids relying on every field
  /// being listed in the constructor (e.g. [patientName] was omitted there).
  AppointmentList _rowToAppointment(Map<String, dynamic> r) {
    final json = <String, dynamic>{
      'appointment_id':         r['appointment_id'],
      'patient_id':             r['patient_id'],
      'queue_id':               r['queue_id'],
      'slot_id':                r['slot_id'],
      'doctor_id':              r['doctor_id'],
      'family_id':              r['family_id'],
      'patient_name':           r['patient_name'],
      'mobile':                 r['mobile'],
      'gender':                 r['gender'],
      'DOB':                    r['DOB'],
      'symptoms':               r['symptoms'],
      'queue_number':           r['queue_number'],
      'booking_type':           r['booking_type'],
      'start_time':             r['start_time'],
      'end_time':               r['end_time'],
      'status':                 r['status'],
      'booking_for':            r['booking_for'],
      'user_type':              r['user_type'],
      'queue_status':           r['queue_status'],
      'my_queue_number':        r['my_queue_number'],
      'patients_ahead':         r['patients_ahead'],
      'estimated_arrival_time': r['estimated_arrival_time'],
      'queue_state':            r['queue_state'],
      // SQLite stores bools as 0/1 integers — convert back to bool for fromJson
      'queue_started':          (r['queue_started'] as int?) == 1,
      'is_my_turn':             (r['is_my_turn'] as int?) == 1,
      'cancelled_by':           r['cancelled_by'],
      'total_queue':            r['total_queue'],
      'current_serving':        r['current_serving'],
      'is_reviewed':            (r['is_reviewed'] as int?) == 1,
      'appointment_date':       r['appointment_date'],
      'doctor_name':            r['doctor_name'],
      'specialization':         r['specialization'],
      'clinic_id':              r['clinic_id'],
      'clinic_name':            r['clinic_name'],
      'clinic_address':         r['clinic_address'],
      'clinic_contact':         r['clinic_contact'],
      'latitude':               r['latitude'],
      'longitude':              r['longitude'],
    };
    return AppointmentList.fromJson(json);
  }
}
