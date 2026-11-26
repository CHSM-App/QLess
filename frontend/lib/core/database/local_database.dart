import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Central SQLite helper for offline-first doctor queue operations.
///
/// Tables:
///   - [_tQueues]      : cached TodayQueueModel rows
///   - [_tAppointments]: cached AppointmentList rows (today's queue patients)
///   - [_tPendingOps]  : queue actions taken offline, waiting to be synced
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static const _dbName    = 'qless_offline.db';
  static const _dbVersion = 8;

  // Table names
  static const _tQueues        = 'queues';
  static const _tAppointments  = 'appointments';
  static const _tPendingOps    = 'pending_operations';
  static const _tPendingRx     = 'pending_prescriptions';
  static const _tMedicines     = 'medicines_cache';
  static const _tPatientAppts  = 'patient_appointments_cache';
  static const _tPatientProfile = 'patient_profile_cache';
  static const _tJsonCache     = 'json_cache';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    // On web the ffi-web factory has no databases directory — getDatabasesPath()
    // throws ("getDatabasesPath is null"). Open with the bare db name instead;
    // on native we still resolve the platform databases path.
    final path = kIsWeb ? _dbName : join(await getDatabasesPath(), _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tQueues (
        queue_id        INTEGER PRIMARY KEY,
        doctor_id       INTEGER,
        queue_date      TEXT,
        slot_id         INTEGER,
        start_time      TEXT,
        end_time        TEXT,
        queue_status    INTEGER,
        current_serving INTEGER,
        current_queue_no INTEGER,
        total_queue     INTEGER,
        completed_count INTEGER,
        started_at      TEXT,
        stopped_at      TEXT,
        booking_closed  INTEGER,
        clinic_id       TEXT,
        updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tAppointments (
        appointment_id      INTEGER PRIMARY KEY,
        patient_id          INTEGER,
        queue_id            INTEGER,
        slot_id             INTEGER,
        doctor_id           INTEGER,
        family_id           INTEGER,
        patient_name        TEXT,
        mobile              TEXT,
        gender              TEXT,
        DOB                 TEXT,
        symptoms            TEXT,
        queue_number        INTEGER,
        booking_type        INTEGER,
        start_time          TEXT,
        end_time            TEXT,
        status              TEXT,
        booking_for         TEXT,
        user_type           INTEGER,
        queue_status        INTEGER,
        my_queue_number     INTEGER,
        patients_ahead      INTEGER,
        estimated_arrival_time TEXT,
        queue_state         TEXT,
        queue_started       INTEGER,
        is_my_turn          INTEGER,
        cancelled_by        TEXT,
        total_queue         INTEGER,
        current_serving     INTEGER,
        is_reviewed         INTEGER,
        appointment_date    TEXT,
        doctor_name         TEXT,
        specialization      TEXT,
        clinic_id           TEXT,
        clinic_name         TEXT,
        clinic_address      TEXT,
        clinic_contact      TEXT,
        latitude            REAL,
        longitude           REAL,
        updated_at          TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // pending_operations: queue actions performed offline
    // operation values: queueStart | queuePause | queueStop | queueNext |
    //                   queueSkip  | queueRecall | queuePauseEmergency |
    //                   startSession | endSession
    await db.execute('''
      CREATE TABLE $_tPendingOps (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        operation       TEXT    NOT NULL,
        payload_json    TEXT    NOT NULL,
        doctor_id       INTEGER,
        queue_id        INTEGER,
        appointment_id  INTEGER,
        created_at      TEXT NOT NULL DEFAULT (datetime('now')),
        retry_count     INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createPendingRxTable(db);
    await _createMedicinesTable(db);
    await _createPatientApptsTable(db);
    await _createPatientProfileTable(db);
    await _migrateV8(db);
  }

  /// v8: pending rows the server rejected (or that can't be decoded) are
  /// parked as `failed` with the reason, instead of being retried forever or
  /// silently deleted. Plus a generic key → JSON cache (doctor schedule etc.).
  Future<void> _migrateV8(Database db) async {
    for (final t in [_tPendingOps, _tPendingRx]) {
      await db.execute('ALTER TABLE $t ADD COLUMN failed INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE $t ADD COLUMN last_error TEXT');
    }
    await db.execute('''
      CREATE TABLE $_tJsonCache (
        cache_key    TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _createPendingRxTable(Database db) async {
    // pending_prescriptions: prescriptions saved offline, waiting to be POSTed
    await db.execute('''
      CREATE TABLE $_tPendingRx (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        payload_json    TEXT    NOT NULL,
        doctor_id       INTEGER,
        appointment_id  INTEGER,
        created_at      TEXT NOT NULL DEFAULT (datetime('now')),
        retry_count     INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createMedicinesTable(Database db) async {
    // medicines_cache: the doctor's medicine catalog, cached so prescriptions
    // can still be written (with medicine selection) while offline.
    await db.execute('''
      CREATE TABLE $_tMedicines (
        medicine_id   INTEGER PRIMARY KEY,
        doctor_id     INTEGER,
        payload_json  TEXT NOT NULL,
        updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _createPatientApptsTable(Database db) async {
    // patient_appointments_cache: a patient's own appointment list, stored as a
    // single JSON blob keyed by the id passed to getPatientAppointments, so the
    // list (upcoming/past) still renders offline.
    await db.execute('''
      CREATE TABLE $_tPatientAppts (
        owner_id     INTEGER PRIMARY KEY,
        payload_json TEXT NOT NULL,
        updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _createPatientProfileTable(Database db) async {
    // patient_profile_cache: the patient's own profile (Patients JSON), keyed
    // by the lookup id (mobile) so the edit screen can prefill offline.
    await db.execute('''
      CREATE TABLE $_tPatientProfile (
        cache_key    TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPendingRxTable(db);
    }
    if (oldVersion < 3) {
      await _createMedicinesTable(db);
    }
    if (oldVersion < 4) {
      await _createPatientApptsTable(db);
    }
    if (oldVersion < 5) {
      await _createPatientProfileTable(db);
    }
    if (oldVersion < 6) {
      // Column was missing entirely — every cacheQueues() write was silently
      // throwing (caught by an empty catch upstream) because TodayQueueModel.
      // toJson() always includes booking_closed, so the queues cache never
      // populated properly and offline reads fell back to bare minimal rows
      // (no start/end time, sessions missing).
      await db.execute('ALTER TABLE $_tQueues ADD COLUMN booking_closed INTEGER');
    }
    if (oldVersion < 7) {
      // Sessions cached with no clinic_id at all — a multi-clinic doctor's
      // sessions from every clinic were mixed under one doctor_id with no way
      // to separate them, so offline could show the wrong clinic's queue.
      await db.execute('ALTER TABLE $_tQueues ADD COLUMN clinic_id TEXT');
    }
    if (oldVersion < 8) {
      await _migrateV8(db);
    }
  }

  // ── Queue cache ─────────────────────────────────────────────────────────────

  Future<void> upsertQueues(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        _tQueues,
        {...row, 'updated_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // The real session for a slot has arrived — drop the offline stand-in
      // (queue_id = -slot_id, see OfflineQueueStore.ensureScheduledSessions).
      final realId = row['queue_id'] as int? ?? 0;
      final date = row['queue_date'] as String?;
      if (realId > 0 && row['slot_id'] != null && date != null && date.length >= 10) {
        batch.delete(_tQueues,
            where: 'queue_id < 0 AND slot_id = ? AND substr(queue_date, 1, 10) = ?',
            whereArgs: [row['slot_id'], date.substring(0, 10)]);
      }
    }
    // Old sessions are never shown (home hides past-dated queues) — prune so
    // the table doesn't grow forever.
    batch.delete(_tQueues,
        where: "queue_date IS NOT NULL AND queue_date < date('now', '-7 days')");
    await batch.commit(noResult: true);
  }

  /// [clinicId] scopes the read to a single clinic when provided — a
  /// multi-clinic doctor's cache holds every clinic's sessions under the same
  /// doctor_id, so an unscoped read here is exactly how the wrong clinic's
  /// queue could show up offline. Rows with a NULL clinic_id (cached before
  /// this column existed, or by an offline optimistic insert that ran before
  /// the clinic was ever confirmed) are still included — a strict equality
  /// match would silently hide a real, previously-visible session instead of
  /// just not being able to tell which clinic it belongs to.
  Future<List<Map<String, dynamic>>> getQueuesForDoctor(int doctorId, {String? clinicId}) async {
    final db = await database;
    if (clinicId != null) {
      return db.query(
        _tQueues,
        where: 'doctor_id = ? AND (clinic_id = ? OR clinic_id IS NULL)',
        whereArgs: [doctorId, clinicId],
        orderBy: 'queue_id DESC',
      );
    }
    return db.query(
      _tQueues,
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'queue_id DESC',
    );
  }

  /// Updates the cached queue's status. If no row is cached yet for this
  /// [queueId] (e.g. the doctor went offline before `getTodayQueue` ever
  /// synced it), a plain UPDATE silently touches zero rows and the session
  /// card would vanish from the offline list entirely. Fall back to inserting
  /// a minimal row so the card still renders (queue_date/start/end unset —
  /// [TodayQueueModel] tolerates nulls for all of these). [clinicId] is only
  /// used for that fallback insert — an existing row already has its clinic
  /// stamped from when it was first cached.
  Future<void> updateQueueStatus(int queueId, int newStatus, {int? doctorId, String? clinicId}) async {
    final db = await database;
    final affected = await db.update(
      _tQueues,
      {
        'queue_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'queue_id = ?',
      whereArgs: [queueId],
    );
    if (affected == 0) {
      await db.insert(
        _tQueues,
        {
          'queue_id': queueId,
          'doctor_id': doctorId,
          'queue_date': DateTime.now().toIso8601String().split('T').first,
          'queue_status': newStatus,
          'clinic_id': clinicId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ── Appointments cache ───────────────────────────────────────────────────────

  Future<void> upsertAppointments(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        _tAppointments,
        {...row, 'updated_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    // Rows are upserted, never deleted by a refresh — prune old ones so the
    // cache doesn't grow forever. Negative ids are offline walk-in
    // placeholders, removed when their booking syncs or is discarded.
    batch.delete(_tAppointments,
        where: "appointment_id > 0 AND appointment_date IS NOT NULL "
            "AND appointment_date < date('now', '-30 days')");
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getAppointmentsForDoctor(
      int doctorId) async {
    final db = await database;
    return db.query(
      _tAppointments,
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'queue_number ASC',
    );
  }

  /// Removes a single cached appointment row — used to drop the placeholder
  /// row created for an offline walk-in booking once the real synced row
  /// (with the server-assigned appointment_id) has landed.
  Future<void> deleteAppointment(int appointmentId) async {
    final db = await database;
    await db.delete(_tAppointments, where: 'appointment_id = ?', whereArgs: [appointmentId]);
  }

  /// Locally mark a patient appointment with a new status (e.g. 'completed',
  /// 'skipped') so the UI reflects the offline action immediately.
  Future<void> updateAppointmentStatus(
      int appointmentId, String newStatus) async {
    final db = await database;
    await db.update(
      _tAppointments,
      {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'appointment_id = ?',
      whereArgs: [appointmentId],
    );
  }

  // ── Pending operations ───────────────────────────────────────────────────────

  Future<int> enqueuePendingOp({
    required String operation,
    required Map<String, dynamic> payload,
    int? doctorId,
    int? queueId,
    int? appointmentId,
  }) async {
    final db = await database;
    return db.insert(_tPendingOps, {
      'operation':      operation,
      'payload_json':   jsonEncode(payload),
      'doctor_id':      doctorId,
      'queue_id':       queueId,
      'appointment_id': appointmentId,
    });
  }

  /// Rows still waiting to sync, oldest first. [doctorId] scopes the read to
  /// one account so rows queued by another doctor on this phone are never
  /// replayed under the current session. Rows with no doctor_id (queued before
  /// it was always stamped) are still included rather than stranded.
  Future<List<Map<String, dynamic>>> getPendingOps({int? doctorId}) =>
      _pending(_tPendingOps, doctorId);

  Future<void> deletePendingOp(int id) => _deleteRow(_tPendingOps, id);

  /// Returns the new retry count.
  Future<int> incrementRetry(int id) => _bumpRetry(_tPendingOps, id);

  Future<void> markOpFailed(int id, String error) =>
      _markFailed(_tPendingOps, id, error);

  Future<int> pendingOpsCount() => _count(_tPendingOps, failed: false);

  // ── Pending prescriptions ────────────────────────────────────────────────────

  /// [payloadJson] must already be a valid JSON string.
  Future<int> enqueuePendingPrescription({
    required String payloadJson,
    int? doctorId,
    int? appointmentId,
  }) async {
    final db = await database;
    return db.insert(_tPendingRx, {
      'payload_json':   payloadJson,
      'doctor_id':      doctorId,
      'appointment_id': appointmentId,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingPrescriptions({int? doctorId}) =>
      _pending(_tPendingRx, doctorId);

  /// Newest unsynced prescription for an appointment — parked ones included,
  /// since the doctor still wrote it and should be able to see it.
  Future<Map<String, dynamic>?> getPendingPrescriptionFor(int appointmentId) async {
    final db = await database;
    final rows = await db.query(_tPendingRx,
        where: 'appointment_id = ?', whereArgs: [appointmentId],
        orderBy: 'id DESC', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> deletePendingPrescription(int id) => _deleteRow(_tPendingRx, id);

  /// Returns the new retry count.
  Future<int> incrementPrescriptionRetry(int id) => _bumpRetry(_tPendingRx, id);

  Future<void> markPrescriptionFailed(int id, String error) =>
      _markFailed(_tPendingRx, id, error);

  Future<int> pendingPrescriptionsCount() => _count(_tPendingRx, failed: false);

  /// A walk-in booked offline has synced: point every queued prescription /
  /// queue op that still uses its placeholder [tempId] at the server's
  /// [realId]. A brand-new patient also only gets a [patientId] now — fill it
  /// in where the payload has none. Without this those rows replay with the
  /// negative id and the server rejects them.
  Future<void> remapAppointment(int tempId, int realId, int? patientId) async {
    final db = await database;
    for (final t in [_tPendingOps, _tPendingRx]) {
      final rows = await db.query(t, columns: ['id', 'payload_json']);
      for (final row in rows) {
        final Map<String, dynamic> payload;
        try {
          payload = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        } catch (_) {
          continue; // corrupt row — the replay loop parks it
        }
        if (payload['appointment_id'] != tempId) continue;
        payload['appointment_id'] = realId;
        final pid = payload['patient_id'];
        if (patientId != null && (pid == null || pid == 0)) payload['patient_id'] = patientId;
        await db.update(
          t,
          {'payload_json': jsonEncode(payload), 'appointment_id': realId},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  /// Drops every queued op / prescription tied to [appointmentId] — used when
  /// the offline walk-in that created it is discarded.
  Future<void> deletePendingForAppointment(int appointmentId) async {
    final db = await database;
    for (final t in [_tPendingOps, _tPendingRx]) {
      await db.delete(t, where: 'appointment_id = ?', whereArgs: [appointmentId]);
    }
  }

  /// A medicine added offline has synced: swap its placeholder [tempId] for
  /// the server's [realId] in queued prescriptions and in the catalog cache.
  Future<void> remapMedicine(int tempId, int realId) async {
    final db = await database;
    for (final row in await db.query(_tPendingRx, columns: ['id', 'payload_json'])) {
      final Map<String, dynamic> payload;
      try {
        payload = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      } catch (_) {
        continue; // corrupt row — the replay loop parks it
      }
      final meds = payload['medicines'];
      if (meds is! List || !meds.any((m) => m is Map && m['medicine_id'] == tempId)) continue;
      for (final m in meds) {
        if (m is Map && m['medicine_id'] == tempId) m['medicine_id'] = realId;
      }
      await db.update(_tPendingRx, {'payload_json': jsonEncode(payload)},
          where: 'id = ?', whereArgs: [row['id']]);
    }
    final cached = await db.query(_tMedicines, where: 'medicine_id = ?', whereArgs: [tempId]);
    if (cached.isNotEmpty) {
      final json = jsonDecode(cached.first['payload_json'] as String) as Map<String, dynamic>;
      await db.delete(_tMedicines, where: 'medicine_id = ?', whereArgs: [tempId]);
      await insertMedicine(realId, cached.first['doctor_id'] as int?,
          jsonEncode({...json, 'medicine_id': realId}));
    }
  }

  // ── Failed (parked) items ────────────────────────────────────────────────────
  // kind: 'op' = pending_operations row, 'rx' = pending_prescriptions row.

  Future<int> failedCount() async =>
      await _count(_tPendingOps, failed: true) +
      await _count(_tPendingRx, failed: true);

  Future<List<Map<String, dynamic>>> getFailedItems() async {
    final db = await database;
    return db.rawQuery('''
      SELECT id, 'op' AS kind, operation, payload_json, appointment_id,
             last_error, created_at
        FROM $_tPendingOps WHERE failed = 1
      UNION ALL
      SELECT id, 'rx' AS kind, 'prescription' AS operation, payload_json,
             appointment_id, last_error, created_at
        FROM $_tPendingRx WHERE failed = 1
      ORDER BY created_at ASC
    ''');
  }

  /// Puts a parked item back in the sync queue.
  Future<void> retryFailed(String kind, int id) async {
    final db = await database;
    await db.update(
      _pendingTable(kind),
      {'failed': 0, 'retry_count': 0, 'last_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePendingItem(String kind, int id) =>
      _deleteRow(_pendingTable(kind), id);

  /// Drops unsynced rows left by a different doctor on this phone (e.g. after
  /// a forced logout) so they are neither sent under this account nor kept.
  Future<void> deletePendingForOtherDoctors(int doctorId) async {
    final db = await database;
    for (final t in [_tPendingOps, _tPendingRx]) {
      await db.delete(t,
          where: 'doctor_id IS NOT NULL AND doctor_id != ?',
          whereArgs: [doctorId]);
    }
  }

  String _pendingTable(String kind) => kind == 'rx' ? _tPendingRx : _tPendingOps;

  Future<List<Map<String, dynamic>>> _pending(String table, int? doctorId) async {
    final db = await database;
    if (doctorId == null) {
      return db.query(table, where: 'failed = 0', orderBy: 'id ASC');
    }
    return db.query(
      table,
      where: 'failed = 0 AND (doctor_id = ? OR doctor_id IS NULL)',
      whereArgs: [doctorId],
      orderBy: 'id ASC',
    );
  }

  Future<void> _deleteRow(String table, int id) async {
    final db = await database;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> _bumpRetry(String table, int id) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE $table SET retry_count = retry_count + 1 WHERE id = ?', [id]);
    final r = await db.query(table,
        columns: ['retry_count'], where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? 0 : (r.first['retry_count'] as int? ?? 0);
  }

  Future<void> _markFailed(String table, int id, String error) async {
    final db = await database;
    await db.update(table, {'failed': 1, 'last_error': error},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> _count(String table, {required bool failed}) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM $table WHERE failed = ?', [failed ? 1 : 0]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Medicines catalog cache ──────────────────────────────────────────────────

  /// Replace the cached catalog for [doctorId]. Each [rows] entry must include
  /// `medicine_id` and a pre-encoded `payload_json` string.
  Future<void> upsertMedicines(
      int doctorId, List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    // Clear the doctor's old catalog first so deletions on the server are
    // reflected, then re-insert the fresh set.
    // Negative ids are medicines added offline and not synced yet — keep them.
    batch.delete(_tMedicines, where: 'doctor_id = ? AND medicine_id > 0', whereArgs: [doctorId]);
    for (final row in rows) {
      batch.insert(
        _tMedicines,
        {...row, 'updated_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Adds (or replaces) one catalog row — a medicine added offline.
  Future<void> insertMedicine(int medicineId, int? doctorId, String payloadJson) async {
    final db = await database;
    await db.insert(
      _tMedicines,
      {
        'medicine_id':  medicineId,
        'doctor_id':    doctorId,
        'payload_json': payloadJson,
        'updated_at':   DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMedicine(int medicineId) async {
    final db = await database;
    await db.delete(_tMedicines, where: 'medicine_id = ?', whereArgs: [medicineId]);
  }

  Future<List<Map<String, dynamic>>> getMedicines(int doctorId) async {
    final db = await database;
    return db.query(
      _tMedicines,
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'medicine_id ASC',
    );
  }

  // ── Patient appointments cache ───────────────────────────────────────────────

  /// [payloadJson] is a pre-encoded JSON array of the patient's appointments.
  Future<void> upsertPatientAppointments(
      int ownerId, String payloadJson) async {
    final db = await database;
    await db.insert(
      _tPatientAppts,
      {
        'owner_id':     ownerId,
        'payload_json': payloadJson,
        'updated_at':   DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getPatientAppointmentsJson(int ownerId) async {
    final db = await database;
    final rows = await db.query(
      _tPatientAppts,
      columns: ['payload_json'],
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['payload_json'] as String?;
  }

  // ── Patient profile cache ────────────────────────────────────────────────────

  Future<void> upsertPatientProfile(String cacheKey, String payloadJson) async {
    final db = await database;
    await db.insert(
      _tPatientProfile,
      {
        'cache_key':    cacheKey,
        'payload_json': payloadJson,
        'updated_at':   DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getPatientProfileJson(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      _tPatientProfile,
      columns: ['payload_json'],
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['payload_json'] as String?;
  }

  // ── Generic JSON cache ───────────────────────────────────────────────────────

  Future<void> upsertJson(String cacheKey, String payloadJson) async {
    final db = await database;
    await db.insert(
      _tJsonCache,
      {
        'cache_key':    cacheKey,
        'payload_json': payloadJson,
        'updated_at':   DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Drops cached JSON under [prefix] older than [days] (json_cache has no
  /// other pruning; per-appointment keys would otherwise grow forever).
  Future<void> pruneJson(String prefix, {int days = 7}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    await db.delete(_tJsonCache,
        where: 'cache_key LIKE ? AND updated_at < ?', whereArgs: ['$prefix%', cutoff]);
  }

  Future<String?> getJson(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      _tJsonCache,
      columns: ['payload_json'],
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['payload_json'] as String?;
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  /// Wipe cached server data but keep unsynced work (pending ops/Rx). Used on
  /// forced logout (session expired) so a doctor who logs straight back in
  /// still gets their offline prescriptions synced.
  Future<void> clearCaches() async {
    final db = await database;
    for (final t in [_tQueues, _tAppointments, _tMedicines, _tPatientAppts,
                     _tPatientProfile, _tJsonCache]) {
      await db.delete(t);
    }
    debugPrint('[LocalDatabase] Cached data cleared (pending work kept).');
  }

  /// Wipe all local data, unsynced work included (voluntary logout).
  Future<void> clearAll() async {
    await clearCaches();
    final db = await database;
    await db.delete(_tPendingOps);
    await db.delete(_tPendingRx);
    debugPrint('[LocalDatabase] All local data cleared.');
  }
}
