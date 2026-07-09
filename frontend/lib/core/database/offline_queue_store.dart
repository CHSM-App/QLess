import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:qless/core/database/local_database.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/domain/models/prescription.dart';
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
  startSession,
  endSession,
  walkInBook,
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
      case OfflineOperation.startSession:        return 'startSession';
      case OfflineOperation.endSession:          return 'endSession';
      case OfflineOperation.walkInBook:          return 'walkInBook';
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
      case 'startSession':        return OfflineOperation.startSession;
      case 'endSession':          return OfflineOperation.endSession;
      case 'walkInBook':          return OfflineOperation.walkInBook;
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

  /// [clinicId] is the clinic this batch was fetched for — stamped onto every
  /// row (overriding whatever the row itself carries, if anything) so the
  /// offline cache can always tell a multi-clinic doctor's sessions apart.
  Future<void> cacheQueues(List<TodayQueueModel> queues, {String? clinicId}) async {
    // SQLite/sqflite has no bool column type — a raw Dart bool in the values
    // map throws on insert. Store booking_closed as 0/1 like the other flags.
    final rows = queues.map((q) => {
          ...q.toJson(),
          'booking_closed': q.bookingClosed ? 1 : 0,
          if (clinicId != null) 'clinic_id': clinicId,
        }).toList();
    await _db.upsertQueues(rows);
  }

  Future<void> cacheAppointments(List<AppointmentList> appointments) async {
    final rows = appointments.map((a) => _appointmentToRow(a)).toList();
    await _db.upsertAppointments(rows);
  }

  // ── Cache reads ──────────────────────────────────────────────────────────────

  Future<List<TodayQueueModel>> getCachedQueues(int doctorId, {String? clinicId}) async {
    final rows = await _db.getQueuesForDoctor(doctorId, clinicId: clinicId);
    // Parse each row defensively — a single malformed cached row (e.g. an int
    // where the model expects a bool) must not blow up the whole offline load
    // and push the screen into a hard error state.
    final out = <TodayQueueModel>[];
    for (final row in rows) {
      try {
        // SQLite stores booking_closed as 0/1 — convert back to bool for
        // fromJson (a raw int there would throw and drop the whole row).
        final json = {...row, 'booking_closed': (row['booking_closed'] as int?) == 1};
        out.add(TodayQueueModel.fromJson(json));
      } catch (e) {
        debugPrint('[OfflineQueueStore] Skipped bad cached queue row: $e');
      }
    }
    return out;
  }

  Future<List<AppointmentList>> getCachedAppointments(int doctorId) async {
    final rows = await _db.getAppointmentsForDoctor(doctorId);
    final out = <AppointmentList>[];
    for (final row in rows) {
      try {
        out.add(_rowToAppointment(row));
      } catch (e) {
        debugPrint('[OfflineQueueStore] Skipped bad cached appointment row: $e');
      }
    }
    return out;
  }

  // ── Optimistic local mutations ───────────────────────────────────────────────

  /// Apply an offline queue state change locally so the UI updates without
  /// waiting for the server. Maps operation → SQLite queue_status value.
  Future<void> applyOfflineQueueOp(
    OfflineOperation op,
    int? queueId,
    int? appointmentId, {
    int? doctorId,
    String? clinicId,
  }) async {
    switch (op) {
      case OfflineOperation.queueStart:
        if (queueId != null) await _db.updateQueueStatus(queueId, 1, doctorId: doctorId, clinicId: clinicId);
        break;
      case OfflineOperation.queuePause:
      case OfflineOperation.queuePauseEmergency:
        if (queueId != null) await _db.updateQueueStatus(queueId, 2, doctorId: doctorId, clinicId: clinicId);
        break;
      case OfflineOperation.queueStop:
        if (queueId != null) await _db.updateQueueStatus(queueId, 3, doctorId: doctorId, clinicId: clinicId);
        break;
      case OfflineOperation.queueNext:
        if (appointmentId != null) {
          await _db.updateAppointmentStatus(appointmentId, 'completed');
          // Online QUEUE_NEXT atomically completes the current patient AND
          // auto-starts the next one server-side — mirror that here so the
          // doctor's next screen and the home list both show a real "current"
          // patient instead of everyone sitting at 'booked' until manually
          // started.
          await _autoAdvance(doctorId, queueId, appointmentId);
        }
        break;
      case OfflineOperation.queueSkip:
        if (appointmentId != null) {
          await _db.updateAppointmentStatus(appointmentId, 'skipped');
          await _autoAdvance(doctorId, queueId, appointmentId);
        }
        break;
      case OfflineOperation.queueRecall:
        if (appointmentId != null) {
          await _db.updateAppointmentStatus(appointmentId, 'pending');
        }
        break;
      case OfflineOperation.startSession:
        // Doctor began consulting this patient — reflect it locally so the
        // consult screen opens and the list shows the patient as active.
        if (appointmentId != null) {
          await _db.updateAppointmentStatus(appointmentId, 'in_progress');
        }
        break;
      case OfflineOperation.endSession:
        // Session closed offline — mark the patient done in the local cache.
        if (appointmentId != null) {
          await _db.updateAppointmentStatus(appointmentId, 'completed');
        }
        break;
      case OfflineOperation.walkInBook:
        // No local queue mutation needed — the booking appears after sync.
        break;
    }
  }

  /// Picks the next booked (non-slot) patient in the same session, today, and
  /// marks it in_progress — the offline mirror of what the server does
  /// atomically inside QUEUE_NEXT / QUEUE_SKIP. Scoped to [queueId] when known
  /// so a doctor running multiple sessions the same day doesn't jump into a
  /// different session's queue. Best-effort: swallows read failures since this
  /// is a secondary UX nicety, not something that should block the primary
  /// complete/skip mutation.
  Future<void> _autoAdvance(
      int? doctorId, int? queueId, int? excludeAppointmentId) async {
    if (doctorId == null) return;
    List<AppointmentList> appts;
    try {
      appts = await getCachedAppointments(doctorId);
    } catch (_) {
      return;
    }
    final today = DateTime.now();
    bool isSlot(AppointmentList a) =>
        a.bookingType == 2 ||
        (a.bookingType == null && a.startTime != null && a.endTime != null);
    final candidates = appts.where((a) {
      if ((a.status ?? '').toLowerCase().trim() != 'booked') return false;
      if (a.appointmentId == excludeAppointmentId) return false;
      if (queueId != null && a.queueId != queueId) return false;
      if (isSlot(a)) return false;
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList()
      ..sort((a, b) => (a.queueNumber ?? 1 << 30).compareTo(b.queueNumber ?? 1 << 30));
    if (candidates.isEmpty) return;
    final nextId = candidates.first.appointmentId;
    if (nextId != null) {
      await _db.updateAppointmentStatus(nextId, 'in_progress');
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

  /// Internal payload key marking the placeholder appointment id — stripped
  /// before the body is ever sent to the server.
  static const _tempApptKey = '_offlineTempApptId';

  /// Enqueue a walk-in booking made while offline. Also inserts a placeholder
  /// row into the appointments cache so the patient shows up in the queue
  /// immediately, the same as a normal online walk-in booking would —
  /// without this, a walk-in booked offline was invisible until the doctor
  /// reconnected and synced.
  Future<void> enqueueWalkInBook(Map<String, dynamic> body, int? doctorId) async {
    final tempId = await _insertOptimisticWalkIn(body, doctorId);
    final payload = tempId == null ? body : {...body, _tempApptKey: tempId};
    await _db.enqueuePendingOp(
      operation: OfflineOperation.walkInBook.name,
      payload:   payload,
      doctorId:  doctorId,
    );
    debugPrint('[OfflineQueueStore] Enqueued offline walkInBook for doctor $doctorId');
  }

  /// Builds the placeholder appointment row. Uses a negative synthetic id —
  /// real appointment ids from the server are always positive — so it can
  /// never collide with a synced row, and is removed once the booking
  /// actually flushes (see [flushPendingWalkIns]).
  Future<int?> _insertOptimisticWalkIn(
      Map<String, dynamic> body, int? doctorId) async {
    if (doctorId == null) return null;
    try {
      final slotId = body['slot_id'] as int?;
      int? queueId;
      if (slotId != null) {
        final queues = await getCachedQueues(doctorId);
        for (final q in queues) {
          if (q.slotId == slotId) { queueId = q.queueId; break; }
        }
      }
      final existing = await getCachedAppointments(doctorId);
      final sameQueue = existing.where((a) => queueId == null || a.queueId == queueId);
      final maxQueueNo = sameQueue.fold<int>(0, (m, a) => (a.queueNumber ?? 0) > m ? a.queueNumber! : m);
      final tempId = -(DateTime.now().microsecondsSinceEpoch % 1000000000);
      await _db.upsertAppointments([{
        'appointment_id':   tempId,
        'patient_id':       body['patient_id'],
        'queue_id':         queueId,
        'doctor_id':        doctorId,
        'patient_name':     body['name'],
        'mobile':           body['mobile_no'],
        'queue_number':     maxQueueNo + 1,
        'booking_type':     1,
        'status':           'booked',
        'user_type':        body['user_type'],
        'appointment_date': body['appointment_date'],
        'clinic_id':        body['clinic_id'],
      }]);
      return tempId;
    } catch (e) {
      debugPrint('[OfflineQueueStore] Optimistic walk-in insert failed: $e');
      return null;
    }
  }

  /// Flush all pending walk-in bookings by calling [executor].
  /// Returns the number successfully sent.
  Future<int> flushPendingWalkIns(
    Future<void> Function(Map<String, dynamic> body) executor,
  ) async {
    final rows = await _db.getPendingOps();
    final walkInRows = rows.where(
      (r) => (r['operation'] as String?) == OfflineOperation.walkInBook.name,
    ).toList();
    if (walkInRows.isEmpty) return 0;

    int flushed = 0;
    for (final row in walkInRows) {
      final id = row['id'] as int;
      try {
        final payload = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        final tempId = payload.remove(_tempApptKey) as int?;
        await executor(payload);
        // Drop the placeholder — the real synced row (server appointment_id)
        // lands separately via the caller's post-flush fetchPatientAppointments.
        if (tempId != null) await _db.deleteAppointment(tempId);
        await deletePendingOp(id);
        flushed++;
        debugPrint('[OfflineQueueStore] Flushed walkInBook op $id');
      } catch (e) {
        await incrementRetry(id);
        debugPrint('[OfflineQueueStore] Failed walkInBook op $id: $e');
      }
    }
    return flushed;
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

  // ── Pending prescriptions ──────────────────────────────────────────────────

  /// Persist a prescription written offline so it can be POSTed on reconnect.
  Future<void> enqueuePrescription(PrescriptionModel prescription) async {
    await _db.enqueuePendingPrescription(
      payloadJson:    jsonEncode(prescription.toJson()),
      doctorId:       prescription.doctorId,
      appointmentId:  prescription.appointmentId,
    );
    debugPrint('[OfflineQueueStore] Enqueued offline prescription '
        '(appt ${prescription.appointmentId})');
  }

  Future<int> pendingPrescriptionsCount() => _db.pendingPrescriptionsCount();

  // ── Medicines catalog cache ────────────────────────────────────────────────

  Future<void> cacheMedicines(int doctorId, List<Medicine> medicines) async {
    final rows = medicines
        .where((m) => m.medicineId != null)
        .map((m) => {
              'medicine_id':  m.medicineId,
              'doctor_id':    doctorId,
              'payload_json': jsonEncode(m.toJson()),
            })
        .toList();
    await _db.upsertMedicines(doctorId, rows);
  }

  Future<List<Medicine>> getCachedMedicines(int doctorId) async {
    final rows = await _db.getMedicines(doctorId);
    final out = <Medicine>[];
    for (final row in rows) {
      try {
        final json =
            jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        out.add(Medicine.fromJson(json));
      } catch (e) {
        debugPrint('[OfflineQueueStore] Skipped bad cached medicine row: $e');
      }
    }
    return out;
  }

  // ── Patient appointments cache ─────────────────────────────────────────────

  /// Cache a patient's appointment list (keyed by the id passed to
  /// getPatientAppointments) so it renders offline.
  Future<void> cachePatientAppointments(
      int ownerId, List<AppointmentList> appointments) async {
    final json = jsonEncode(appointments.map((a) => a.toJson()).toList());
    await _db.upsertPatientAppointments(ownerId, json);
  }

  Future<List<AppointmentList>> getCachedPatientAppointments(
      int ownerId) async {
    final raw = await _db.getPatientAppointmentsJson(ownerId);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AppointmentList.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[OfflineQueueStore] Bad cached patient appointments: $e');
      return const [];
    }
  }

  // ── Patient profile cache ──────────────────────────────────────────────────

  /// Cache the patient's own profile list (keyed by the lookup id, e.g. mobile)
  /// so the edit/profile screen prefills offline.
  Future<void> cachePatientProfile(
      String cacheKey, List<Patients> profile) async {
    final json = jsonEncode(profile.map((p) => p.toJson()).toList());
    await _db.upsertPatientProfile(cacheKey, json);
  }

  Future<List<Patients>> getCachedPatientProfile(String cacheKey) async {
    final raw = await _db.getPatientProfileJson(cacheKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Patients.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[OfflineQueueStore] Bad cached patient profile: $e');
      return const [];
    }
  }

  /// Flush all offline prescriptions by POSTing them via [executor].
  /// Returns the number successfully sent.
  Future<int> flushPendingPrescriptions(
    Future<void> Function(PrescriptionModel prescription) executor,
  ) async {
    final rows = await _db.getPendingPrescriptions();
    if (rows.isEmpty) return 0;

    int flushed = 0;
    for (final row in rows) {
      final id = row['id'] as int;
      try {
        final json =
            jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        await executor(PrescriptionModel.fromJson(json));
        await _db.deletePendingPrescription(id);
        flushed++;
        debugPrint('[OfflineQueueStore] Flushed prescription $id');
      } catch (e) {
        await _db.incrementPrescriptionRetry(id);
        debugPrint('[OfflineQueueStore] Failed prescription $id: $e');
      }
    }
    return flushed;
  }

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
