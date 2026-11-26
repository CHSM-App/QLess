import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:qless/core/database/local_database.dart';
import 'package:qless/core/network/network_errors.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/doctor_leave_model.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
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
  addMedicine,
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
      case OfflineOperation.addMedicine:         return 'addMedicine';
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
      case 'addMedicine':         return OfflineOperation.addMedicine;
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

  /// Bumped whenever work is queued, so the sync controller can send it right
  /// away instead of waiting for the next connectivity change or timer tick.
  final changes = ValueNotifier<int>(0);
  void _changed() => changes.value++;

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

  // ── Sessions from the schedule ───────────────────────────────────────────────

  static const _weekdays = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
  ];

  /// Offline, today's sessions may never have been downloaded (app opened
  /// with no internet) or may not exist on the server yet (nobody booked).
  /// For each of today's queue-type schedule slots with no cached session,
  /// adds one with queue_id = -slot_id so the doctor can still start it. The
  /// server turns that id back into the real queue when the actions sync
  /// (resolveTempQueue); [LocalDatabase.upsertQueues] drops it once the real
  /// row is downloaded.
  Future<void> ensureScheduledSessions(int doctorId, {String? clinicId}) async {
    final raw = await getCachedJson('schedule:$doctorId:${clinicId ?? ''}');
    if (raw is! Map<String, dynamic>) return;
    final now = DateTime.now();

    final leaves = await getCachedJson('leaves:$doctorId');
    if (leaves is List &&
        leaves.any((l) {
          try {
            return LeaveRange.fromJson(l as Map<String, dynamic>).contains(now);
          } catch (_) {
            return false;
          }
        })) {
      return;
    }

    final dayName = _weekdays[now.weekday - 1];
    final day = (DoctorScheduleModel.fromJson(raw).schedule ?? const [])
        .where((d) => (d.day ?? '').toLowerCase() == dayName && (d.isEnabled ?? 0) == 1)
        .firstOrNull;
    if (day == null) return;

    String two(int n) => n.toString().padLeft(2, '0');
    final today = '${now.year}-${two(now.month)}-${two(now.day)}';
    final cachedSlots = (await _db.getQueuesForDoctor(doctorId, clinicId: clinicId))
        .where((r) => (r['queue_date'] as String? ?? '').startsWith(today))
        .map((r) => r['slot_id'] as int?)
        .toSet();

    final rows = <Map<String, dynamic>>[];
    for (final s in day.slots ?? const <TimeSlotModel>[]) {
      final slotId = s.slotId;
      final start = s.startTime;
      final end = s.endTime;
      if (slotId == null || start == null || end == null) continue;
      if (cachedSlots.contains(slotId)) continue;
      if (s.bookingMode != 1 && s.bookingMode != 3) continue; // slots-only has no queue
      final endParts = end.split(':');
      final endAt = DateTime(now.year, now.month, now.day,
          int.tryParse(endParts[0]) ?? 23, int.tryParse(endParts.elementAtOrNull(1) ?? '') ?? 59);
      if (now.isAfter(endAt)) continue;
      rows.add({
        'queue_id':       -slotId,
        'doctor_id':      doctorId,
        'queue_date':     today,
        'slot_id':        slotId,
        // same shape the server sends for a SQL time column
        'start_time':     '1970-01-01T${start.substring(0, 5)}:00.000Z',
        'end_time':       '1970-01-01T${end.substring(0, 5)}:00.000Z',
        'queue_status':   0,
        'booking_closed': 0,
        'clinic_id':      clinicId,
      });
    }
    if (rows.isNotEmpty) await _db.upsertQueues(rows);
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
      case OfflineOperation.addMedicine:
        break; // the catalog cache is updated when it is queued
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
    // Someone in this session is already in progress — the advance already
    // happened (reapplyPendingOps can run a queueNext over the same rows
    // twice); starting another would put two patients in progress.
    if (appts.any((a) =>
        (a.status ?? '').toLowerCase().trim() == 'in_progress' &&
        a.appointmentId != excludeAppointmentId &&
        (queueId == null || a.queueId == queueId) &&
        !isSlot(a))) {
      return;
    }
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

  /// Stamped into every queued payload so the backend can tell a late replay
  /// from a live action (and skip stale "your turn" pushes to patients).
  static Map<String, dynamic> _stamp(Map<String, dynamic> payload) =>
      {...payload, 'offline_queued_at': DateTime.now().toUtc().toIso8601String()};

  Future<void> enqueueOp(
    OfflineOperation op,
    AppointmentRequestModel request, {
    int? queueId,
  }) async {
    await _db.enqueuePendingOp(
      operation:     op.name,
      payload:       _stamp(request.toJson()),
      doctorId:      request.doctorId,
      queueId:       queueId ?? request.queueId,
      appointmentId: request.appointmentId,
    );
    debugPrint('[OfflineQueueStore] Enqueued offline op: ${op.name}');
    _changed();
  }

  /// Re-applies the queue actions still waiting to sync on top of freshly
  /// downloaded server rows, so a refresh before the sync finishes doesn't
  /// bring back a patient the doctor already completed offline.
  Future<void> reapplyPendingOps(int doctorId) async {
    final rows = (await _db.getPendingOps(doctorId: doctorId)).where((r) =>
        r['operation'] != OfflineOperation.walkInBook.name &&
        r['operation'] != OfflineOperation.addMedicine.name);
    for (final row in rows) {
      try {
        final op = PendingOperation.fromRow(row);
        await applyOfflineQueueOp(op.operation, op.queueId, op.appointmentId,
            doctorId: doctorId, clinicId: op.payload['clinic_id']?.toString());
      } catch (e) {
        debugPrint('[OfflineQueueStore] Re-apply skipped row ${row['id']}: $e');
      }
    }
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
    // A doctor (not receptionist) booking a walk-in has no doctorId on the
    // receptionist state — the body always carries it.
    doctorId ??= body['doctor_id'] as int?;
    final tempId = await _insertOptimisticWalkIn(body, doctorId);
    final payload = _stamp(tempId == null ? body : {...body, _tempApptKey: tempId});
    await _db.enqueuePendingOp(
      operation: OfflineOperation.walkInBook.name,
      payload:   payload,
      doctorId:  doctorId,
    );
    debugPrint('[OfflineQueueStore] Enqueued offline walkInBook for doctor $doctorId');
    _changed();
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

  /// Flush pending walk-in bookings for [doctorId] by calling [executor].
  /// Returns the number successfully sent.
  Future<int> flushPendingWalkIns(
    Future<AppointmentResponseModel> Function(Map<String, dynamic> body) executor, {
    int? doctorId,
  }) async {
    final rows = (await _db.getPendingOps(doctorId: doctorId))
        .where((r) => r['operation'] == OfflineOperation.walkInBook.name)
        .toList();
    return _flush(
      rows,
      send: (row) async {
        final payload = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        final tempId = payload.remove(_tempApptKey) as int?;
        final res = await executor(payload);
        _checkSuccess(res.success, res.message);
        if (tempId != null) {
          // Prescriptions / queue ops queued against the placeholder now point
          // at the real appointment (they replay after walk-ins).
          if (res.appointmentId != null) {
            await _db.remapAppointment(tempId, res.appointmentId!, res.patientId);
          }
          // Drop the placeholder — the real synced row lands separately via
          // the caller's post-flush fetchPatientAppointments.
          await _db.deleteAppointment(tempId);
        }
      },
      onSent: _db.deletePendingOp,
      markFailed: _db.markOpFailed,
      bumpRetry: _db.incrementRetry,
    );
  }

  Future<void> enqueueEmergencyPause(int queueId, int? doctorId) async {
    await _db.enqueuePendingOp(
      operation: OfflineOperation.queuePauseEmergency.name,
      payload:   _stamp({'queue_id': queueId, 'doctor_id': doctorId}),
      doctorId:  doctorId,
      queueId:   queueId,
    );
    debugPrint('[OfflineQueueStore] Enqueued offline emergency pause: $queueId');
    _changed();
  }

  // ── Medicines added offline ────────────────────────────────────────────────

  /// Payload key for a medicine's placeholder id (negative, never a server
  /// id) — stripped before the body is sent.
  static const _tempMedKey = '_offlineTempMedId';

  /// Saves a medicine added offline: it goes into the catalog cache straight
  /// away with a negative id (so it can be prescribed now) and is queued for
  /// insertMedicine. Returns the placeholder id.
  Future<int> enqueueAddMedicine(Medicine medicine) async {
    final tempId = -(DateTime.now().microsecondsSinceEpoch % 1000000000);
    final doctorId = medicine.doctorId;
    final json = {...medicine.toJson(), 'medicine_id': tempId};
    await _db.insertMedicine(tempId, doctorId, jsonEncode(json));
    await _db.enqueuePendingOp(
      operation: OfflineOperation.addMedicine.name,
      payload:   _stamp({...medicine.toJson(), _tempMedKey: tempId}..remove('medicine_id')),
      doctorId:  doctorId,
    );
    debugPrint('[OfflineQueueStore] Enqueued offline medicine ${medicine.medicineName}');
    _changed();
    return tempId;
  }

  /// Sends medicines added offline. Each one's placeholder id is swapped for
  /// the server's in queued prescriptions and in the catalog cache.
  Future<int> flushPendingMedicines(
    Future<dynamic> Function(Map<String, dynamic> body) executor, {
    int? doctorId,
  }) async {
    final rows = (await _db.getPendingOps(doctorId: doctorId))
        .where((r) => r['operation'] == OfflineOperation.addMedicine.name)
        .toList();
    return _flush(
      rows,
      send: (row) async {
        final payload = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        final tempId = payload.remove(_tempMedKey) as int?;
        final res = await executor(payload);
        if (res is! Map) throw Exception('Unexpected server response');
        final ok = res['success'];
        _checkSuccess(ok == true || ok == 1, res['message']?.toString());
        final realId = (res['medicine_id'] as num?)?.toInt();
        if (tempId != null && realId != null) {
          await _db.remapMedicine(tempId, realId);
        }
      },
      onSent: _db.deletePendingOp,
      markFailed: _db.markOpFailed,
      bumpRetry: _db.incrementRetry,
    );
  }

  /// Everything still waiting to sync — queue ops, walk-ins and prescriptions.
  Future<int> pendingOpsCount() async =>
      await _db.pendingOpsCount() + await _db.pendingPrescriptionsCount();

  // ── Failed (parked) items ──────────────────────────────────────────────────

  Future<int> failedCount() => _db.failedCount();

  /// Rows with `kind` ('op' | 'rx'), `id`, `operation`, `appointment_id`,
  /// `last_error`, `created_at`, `payload_json`.
  Future<List<Map<String, dynamic>>> getFailedItems() => _db.getFailedItems();

  Future<void> retryFailed(String kind, int id) => _db.retryFailed(kind, id);

  /// Throws the item away. A discarded walk-in also loses its placeholder row
  /// so it stops showing in the offline queue.
  Future<void> discardFailed(String kind, int id) async {
    if (kind == 'op') {
      final item = (await _db.getFailedItems())
          .where((r) => r['kind'] == 'op' && r['id'] == id)
          .firstOrNull;
      try {
        final payload = jsonDecode(item?['payload_json'] as String? ?? '{}');
        final tempId = payload is Map ? payload[_tempApptKey] as int? : null;
        if (tempId != null) {
          await _db.deleteAppointment(tempId);
          // what was queued for that walk-in can never sync either
          await _db.deletePendingForAppointment(tempId);
        }
        final tempMed = payload is Map ? payload[_tempMedKey] as int? : null;
        if (tempMed != null) await _db.deleteMedicine(tempMed);
      } catch (_) {} // corrupt payload — nothing to clean up
    }
    await _db.deletePendingItem(kind, id);
  }

  Future<void> deletePendingForOtherDoctors(int doctorId) =>
      _db.deletePendingForOtherDoctors(doctorId);

  // ── Replay loop ────────────────────────────────────────────────────────────

  static const _maxRetries = 5;

  /// Throws [_Rejected] when the server answered `success: false` (HTTP 200
  /// with a refusal, e.g. "Doctor is on leave") — retrying won't change it.
  void _checkSuccess(bool? success, String? message) {
    if (success == false) throw _Rejected(message ?? 'Rejected by server');
  }

  /// Shared replay loop for every pending table, oldest row first:
  ///  * sent            → [onSent] (row deleted)
  ///  * network error   → stop here; this and later rows stay pending, in order
  ///  * server said no  → park as failed with the reason (shown to the doctor)
  ///  * corrupt row     → park as failed so it can never block the rest
  ///  * anything else   → retry next time; park after [_maxRetries] attempts
  Future<int> _flush(
    List<Map<String, dynamic>> rows, {
    required Future<void> Function(Map<String, dynamic> row) send,
    required Future<void> Function(int id) onSent,
    required Future<void> Function(int id, String error) markFailed,
    required Future<int> Function(int id) bumpRetry,
  }) async {
    int sent = 0;
    for (final row in rows) {
      final id = row['id'] as int;
      try {
        await send(row);
        await onSent(id);
        sent++;
      } catch (e) {
        if (e is _Rejected) {
          await markFailed(id, e.message);
        } else if (isServerRejection(e)) {
          await markFailed(id, errorMessage(e));
        } else if (e is FormatException || e is TypeError || e is ArgumentError) {
          await markFailed(id, 'Corrupt offline data: $e');
        } else if (isNetworkError(e)) {
          debugPrint('[OfflineQueueStore] Network down mid-sync, stopping at row $id');
          break;
        } else if (e is DioException && e.response?.statusCode == 401) {
          // Token refresh failed (often a flaky link right after reconnect).
          // Not this row's fault — stop and retry on the next sync uncounted.
          debugPrint('[OfflineQueueStore] Not signed in mid-sync, stopping at row $id');
          break;
        } else if (await bumpRetry(id) >= _maxRetries) {
          await markFailed(id, errorMessage(e));
        }
        debugPrint('[OfflineQueueStore] Row $id not synced: $e');
      }
    }
    return sent;
  }

  /// Rows tied to a walk-in booked offline carry its placeholder (negative)
  /// appointment id until the walk-in syncs and [LocalDatabase.remapAppointment]
  /// swaps it. Sent before that, the server refuses them and they'd be parked
  /// for good — so hold them back while the walk-in is still waiting, and park
  /// them only once the walk-in itself failed or was discarded.
  Future<List<Map<String, dynamic>>> _withoutUnsyncedWalkIns(
    List<Map<String, dynamic>> rows,
    Future<void> Function(int id, String error) markFailed, {
    int? doctorId,
  }) async {
    if (!rows.any((r) => (r['appointment_id'] as int? ?? 0) < 0)) return rows;
    final waiting = <int>{};
    for (final r in await _db.getPendingOps(doctorId: doctorId)) {
      if (r['operation'] != OfflineOperation.walkInBook.name) continue;
      try {
        final temp = (jsonDecode(r['payload_json'] as String) as Map)[_tempApptKey];
        if (temp is int) waiting.add(temp);
      } catch (_) {}
    }
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final appt = r['appointment_id'] as int? ?? 0;
      if (appt >= 0) {
        out.add(r);
      } else if (!waiting.contains(appt)) {
        await markFailed(r['id'] as int, 'Walk-in booking did not sync');
      }
    }
    return out;
  }

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
    _changed();
  }

  Future<int> pendingPrescriptionsCount() => _db.pendingPrescriptionsCount();

  // ── Prescriptions for offline viewing ──────────────────────────────────────

  static String _rxKey(int appointmentId) => 'rx:appt:$appointmentId';

  /// Server rows of an appointment's prescription, kept for offline viewing.
  Future<void> cacheAppointmentPrescription(
          int appointmentId, List<PrescriptionModel> rows) =>
      cacheJson(_rxKey(appointmentId), rows.map((r) => r.toJson()).toList());

  Future<bool> hasCachedAppointmentPrescription(int appointmentId) async =>
      await _db.getJson(_rxKey(appointmentId)) != null;

  Future<void> pruneCachedPrescriptions() => _db.pruneJson('rx:');

  /// An appointment's prescription without the network, in the same flat
  /// one-row-per-medicine shape the server returns: the cached server copy,
  /// else the one written offline and not yet synced. Empty when neither.
  Future<List<PrescriptionModel>> offlineAppointmentPrescription(
      int appointmentId, {int? doctorId}) async {
    final cached = await getCachedJson(_rxKey(appointmentId));
    if (cached is List && cached.isNotEmpty) {
      try {
        return cached
            .map((e) => PrescriptionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('[OfflineQueueStore] Bad cached prescription: $e');
      }
    }

    final row = await _db.getPendingPrescriptionFor(appointmentId);
    if (row == null) return const [];
    try {
      final payload = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      final meds = (payload.remove('medicines') as List?) ?? const [];
      final header = <String, dynamic>{
        ...payload,
        'prescription_date': payload['prescription_date'] ?? row['created_at'],
      };
      // The queued payload has ids only — names come from the local caches.
      final docId = doctorId ?? payload['doctor_id'] as int?;
      if (docId != null) {
        final appt = (await getCachedAppointments(docId))
            .where((a) => a.appointmentId == appointmentId).firstOrNull;
        if (appt?.patientName != null) header['patient_name'] = appt!.patientName;
      }
      final names = <int, Medicine>{
        if (docId != null)
          for (final m in await getCachedMedicines(docId))
            if (m.medicineId != null) m.medicineId!: m,
      };
      if (meds.isEmpty) return [PrescriptionModel.fromJson(header)];
      return [
        for (final m in meds.cast<Map<String, dynamic>>())
          PrescriptionModel.fromJson({
            ...header,
            ...m,
            'medicine_name': names[m['medicine_id']]?.medicineName,
            'Medi_Type_Name': names[m['medicine_id']]?.medTypeName,
          }),
      ];
    } catch (e) {
      debugPrint('[OfflineQueueStore] Bad pending prescription: $e');
      return const [];
    }
  }

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

  // ── Generic JSON cache (doctor schedule, leaves, …) ────────────────────────

  Future<void> cacheJson(String key, Object? value) =>
      _db.upsertJson(key, jsonEncode(value));

  /// Decoded value, or null when nothing is cached (or the row is corrupt).
  Future<dynamic> getCachedJson(String key) async {
    final raw = await _db.getJson(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
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
    Future<dynamic> Function(PrescriptionModel prescription) executor, {
    int? doctorId,
  }) async {
    return _flush(
      await _withoutUnsyncedWalkIns(
          await _db.getPendingPrescriptions(doctorId: doctorId),
          _db.markPrescriptionFailed,
          doctorId: doctorId),
      send: (row) async {
        final json = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        final res = await executor(PrescriptionModel.fromJson(json));
        // Only a JSON `success: true` counts as saved. Anything else (e.g. a
        // captive-portal HTML page with 200) would otherwise delete the row.
        if (res is! Map) throw Exception('Unexpected server response');
        final ok = res['success'];
        _checkSuccess(ok == true || ok == 1, res['message']?.toString());
      },
      onSent: _db.deletePendingPrescription,
      markFailed: _db.markPrescriptionFailed,
      bumpRetry: _db.incrementPrescriptionRetry,
    );
  }

  /// Flush pending queue operations for [doctorId] by executing them against
  /// the API. Walk-ins live in the same table but are replayed separately by
  /// [flushPendingWalkIns] — they must never be consumed here.
  ///
  /// [executor] is a callback from the ViewModel that knows how to call each
  /// operation. Returns the number of successfully flushed ops.
  Future<int> flushPendingOps(
    Future<AppointmentResponseModel> Function(
      OfflineOperation op,
      Map<String, dynamic> payload,
    ) executor, {
    int? doctorId,
  }) async {
    final rows = (await _db.getPendingOps(doctorId: doctorId))
        .where((r) =>
            r['operation'] != OfflineOperation.walkInBook.name &&
            r['operation'] != OfflineOperation.addMedicine.name)
        .toList();
    return _flush(
      await _withoutUnsyncedWalkIns(rows, _db.markOpFailed, doctorId: doctorId),
      send: (row) async {
        final op = PendingOperation.fromRow(row);
        final res = await executor(op.operation, op.payload);
        _checkSuccess(res.success, res.message);
      },
      onSent: _db.deletePendingOp,
      markFailed: _db.markOpFailed,
      bumpRetry: _db.incrementRetry,
    );
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

/// The server answered but refused the replayed action.
class _Rejected implements Exception {
  final String message;
  _Rejected(this.message);
  @override
  String toString() => message;
}
