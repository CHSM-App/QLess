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
  static const _dbVersion = 1;

  // Table names
  static const _tQueues        = 'queues';
  static const _tAppointments  = 'appointments';
  static const _tPendingOps    = 'pending_operations';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, _dbName);

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
    //                   queueSkip  | queueRecall | queuePauseEmergency
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
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
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getQueuesForDoctor(int doctorId) async {
    final db = await database;
    return db.query(
      _tQueues,
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'queue_id DESC',
    );
  }

  Future<void> updateQueueStatus(int queueId, int newStatus) async {
    final db = await database;
    await db.update(
      _tQueues,
      {
        'queue_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'queue_id = ?',
      whereArgs: [queueId],
    );
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
    // Convert payload to JSON string inline — avoid importing dart:convert at
    // call-sites that already pass a decoded Map.
    final payloadJson = _mapToJsonString(payload);
    return db.insert(_tPendingOps, {
      'operation':      operation,
      'payload_json':   payloadJson,
      'doctor_id':      doctorId,
      'queue_id':       queueId,
      'appointment_id': appointmentId,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOps() async {
    final db = await database;
    return db.query(_tPendingOps, orderBy: 'id ASC');
  }

  Future<void> deletePendingOp(int id) async {
    final db = await database;
    await db.delete(_tPendingOps, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetry(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE $_tPendingOps SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<int> pendingOpsCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM $_tPendingOps');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Minimal JSON encode without importing dart:convert at every call-site.
  String _mapToJsonString(Map<String, dynamic> map) {
    // We rely on Dart's toString for primitives. Using dart:convert here is
    // safe since this file already targets Flutter (not a pure Dart library).
    // ignore: avoid_dynamic_calls
    final buffer = StringBuffer('{');
    bool first = true;
    map.forEach((k, v) {
      if (!first) buffer.write(',');
      first = false;
      buffer.write('"$k":');
      if (v == null) {
        buffer.write('null');
      } else if (v is String) {
        buffer.write('"${v.replaceAll('"', '\\"')}"');
      } else if (v is bool) {
        buffer.write(v ? 'true' : 'false');
      } else {
        buffer.write(v);
      }
    });
    buffer.write('}');
    return buffer.toString();
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  /// Wipe all local data (use for logout / account switch).
  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_tQueues);
    await db.delete(_tAppointments);
    await db.delete(_tPendingOps);
    debugPrint('[LocalDatabase] All local data cleared.');
  }
}
