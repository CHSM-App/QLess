import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/database/offline_queue_store.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/today_queue_model.dart';
import 'package:qless/domain/usecase/appointment_usecase.dart';

enum QueueState { idle, running, paused, stopped }

// ─── State ────────────────────────────────────────────────────────────────────

class AppointmentListState {
  final bool isLoading;
  final String? error;
  final AsyncValue<List<AppointmentList>> patientAppointmentsList;
  final AsyncValue<List<TodayQueueModel>>? todayQueueResult;
  final QueueState queueState;
  final int? doctorPatientCount;
  // Queue IDs the doctor has emergency-paused this session. The backend uses a
  // distinct status for emergency pause; we track it client-side so the card
  // shows "Resume" (treated as paused) and a re-tap can warn "already paused".
  final Set<int> emergencyQueueIds;
  /// Number of pending offline operations waiting to be synced.
  final int pendingOpsCount;

  const AppointmentListState({
    this.isLoading = false,
    this.error,
    this.patientAppointmentsList = const AsyncValue.data([]),
    this.queueState = QueueState.idle,
    this.todayQueueResult = const AsyncValue.data([]),
    this.doctorPatientCount,
    this.emergencyQueueIds = const {},
    this.pendingOpsCount = 0,
  });

  AppointmentListState copyWith({
    bool? isLoading,
    String? error,
    AsyncValue<List<AppointmentList>>? patientAppointmentsList,
    AsyncValue<List<TodayQueueModel>>? todayQueueResult,
    QueueState? queueState,
    int? doctorPatientCount,
    Set<int>? emergencyQueueIds,
    int? pendingOpsCount,
  }) {
    return AppointmentListState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      patientAppointmentsList:
          patientAppointmentsList ?? this.patientAppointmentsList,
      queueState: queueState ?? this.queueState,
      todayQueueResult: todayQueueResult ?? this.todayQueueResult,
      doctorPatientCount: doctorPatientCount ?? this.doctorPatientCount,
      emergencyQueueIds: emergencyQueueIds ?? this.emergencyQueueIds,
      pendingOpsCount: pendingOpsCount ?? this.pendingOpsCount,
    );
  }
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

class AppointmentListViewmodel extends StateNotifier<AppointmentListState> {
  final AppointmentUsecase usecase;
  final OfflineQueueStore offlineStore;

  AppointmentListViewmodel(this.usecase, this.offlineStore)
      : super(const AppointmentListState());

  // ── Fetch ──────────────────────────────────────────────────────────────────

  /// Offline-first fetch: tries the network, falls back to SQLite cache.
  Future<void> fetchPatientAppointments(int doctorId,
      {bool isOnline = true}) async {
    state = state.copyWith(
      patientAppointmentsList: const AsyncValue.loading(),
      error: null,
    );
    try {
      if (isOnline) {
        final result = await usecase.fetchPatientAppointments(doctorId);
        // Cache the fresh data locally
        await offlineStore.cacheAppointments(result);

        final derivedQueueState = _deriveQueueState(
            result.isNotEmpty ? result.first.queueStatus : null);

        List<TodayQueueModel> todayQueues = [];
        try {
          todayQueues = await usecase.getTodayQueue(doctorId);
          await offlineStore.cacheQueues(todayQueues);
        } catch (_) {}

        final emIds = state.emergencyQueueIds;
        final pendingCount = await offlineStore.pendingOpsCount();
        state = state.copyWith(
          patientAppointmentsList: AsyncValue.data(result),
          queueState: _adjustForEmergency(derivedQueueState, result, emIds),
          todayQueueResult:
              AsyncValue.data(_applyEmergency(todayQueues, emIds)),
          pendingOpsCount: pendingCount,
        );
      } else {
        // Offline: load from local SQLite cache
        await _loadFromCache(doctorId);
      }
    } catch (e) {
      // Network error — fall back to cache
      debugPrint('[AppointmentVM] Network fetch failed, loading cache: $e');
      try {
        await _loadFromCache(doctorId);
      } catch (cacheErr) {
        state = state.copyWith(
            patientAppointmentsList: AsyncValue.error(cacheErr, StackTrace.current));
      }
    }
  }

  Future<void> _loadFromCache(int doctorId) async {
    final cachedAppts  = await offlineStore.getCachedAppointments(doctorId);
    final cachedQueues = await offlineStore.getCachedQueues(doctorId);
    final pendingCount = await offlineStore.pendingOpsCount();

    final derivedQueueState = _deriveQueueState(
        cachedAppts.isNotEmpty ? cachedAppts.first.queueStatus : null);
    final emIds = state.emergencyQueueIds;

    state = state.copyWith(
      patientAppointmentsList: AsyncValue.data(cachedAppts),
      todayQueueResult:
          AsyncValue.data(_applyEmergency(cachedQueues, emIds)),
      queueState: _adjustForEmergency(derivedQueueState, cachedAppts, emIds),
      pendingOpsCount: pendingCount,
    );
  }

  QueueState _deriveQueueState(int? queueStatus) {
    switch (queueStatus) {
      case 1:
        return QueueState.running; // QUEUE_START
      case 2:
        return QueueState.paused; // QUEUE_PAUSE
      case 3:
        return QueueState.stopped; // QUEUE_STOP
      default:
        return QueueState.idle; // no queue row yet
    }
  }

  List<TodayQueueModel> _applyEmergency(
      List<TodayQueueModel> queues, Set<int> emIds) {
    if (emIds.isEmpty) return queues;
    return queues
        .map((q) => (q.queueId != null && emIds.contains(q.queueId))
            ? q.copyWith(queueStatus: 2)
            : q)
        .toList();
  }

  QueueState _adjustForEmergency(
      QueueState derived, List<AppointmentList> appts, Set<int> emIds) {
    if (emIds.isEmpty ||
        derived == QueueState.running ||
        derived == QueueState.stopped) {
      return derived;
    }
    final firstQueueId = appts.isNotEmpty ? appts.first.queueId : null;
    if (firstQueueId != null && emIds.contains(firstQueueId)) {
      return QueueState.paused;
    }
    return derived;
  }

  void _clearEmergency(int? queueId) {
    if (queueId == null || !state.emergencyQueueIds.contains(queueId)) return;
    state = state.copyWith(
      emergencyQueueIds: {...state.emergencyQueueIds}..remove(queueId),
    );
  }

  bool isEmergencyPaused(int? queueId) =>
      queueId != null && state.emergencyQueueIds.contains(queueId);

  Future<void> fetchDoctorPatientCount(int doctorId,
      {bool isOnline = true}) async {
    try {
      List<AppointmentList> result;
      if (isOnline) {
        result = await usecase.fetchPatientAppointments(doctorId);
      } else {
        result = await offlineStore.getCachedAppointments(doctorId);
      }
      final count =
          result.where((a) => a.status?.toLowerCase() == 'completed').length;
      state = state.copyWith(doctorPatientCount: count);
    } catch (_) {
      // Non-critical — count just won't show
    }
  }

  // ── Queue Start ─────────────────────────────────────────────────────────────

  Future<AppointmentResponseModel> queueStart(
    AppointmentRequestModel appointmentRequest, {
    bool isOnline = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (isOnline) {
        final result = await usecase.queueStart(appointmentRequest);
        _clearEmergency(appointmentRequest.queueId);
        await fetchPatientAppointments(appointmentRequest.doctorId!,
            isOnline: true);
        state =
            state.copyWith(isLoading: false, queueState: QueueState.running);
        return result;
      } else {
        return await _offlineQueueOp(
          op: OfflineOperation.queueStart,
          request: appointmentRequest,
          newQueueState: QueueState.running,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Queue Pause ─────────────────────────────────────────────────────────────

  Future<AppointmentResponseModel> queuePause(
    AppointmentRequestModel appointmentRequest, {
    bool isOnline = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (isOnline) {
        final result = await usecase.queuePause(appointmentRequest);
        _clearEmergency(appointmentRequest.queueId);
        await fetchPatientAppointments(appointmentRequest.doctorId!,
            isOnline: true);
        state = state.copyWith(isLoading: false, queueState: QueueState.paused);
        return result;
      } else {
        return await _offlineQueueOp(
          op: OfflineOperation.queuePause,
          request: appointmentRequest,
          newQueueState: QueueState.paused,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Queue Stop ──────────────────────────────────────────────────────────────

  Future<AppointmentResponseModel> queueStop(
    AppointmentRequestModel appointmentRequest, {
    bool isOnline = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (isOnline) {
        final result = await usecase.queueStop(appointmentRequest);
        _clearEmergency(appointmentRequest.queueId);
        await fetchPatientAppointments(appointmentRequest.doctorId!,
            isOnline: true);
        state =
            state.copyWith(isLoading: false, queueState: QueueState.stopped);
        return result;
      } else {
        return await _offlineQueueOp(
          op: OfflineOperation.queueStop,
          request: appointmentRequest,
          newQueueState: QueueState.stopped,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Queue Next (Mark Complete) ──────────────────────────────────────────────

  Future<AppointmentResponseModel> queueNext(
    AppointmentRequestModel appointmentRequest, {
    bool isOnline = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (isOnline) {
        debugPrint('QueueNext VM request: ${appointmentRequest.toJson()}');
        final result = await usecase.queueNext(appointmentRequest);
        debugPrint('QueueNext VM response: ${result.toJson()}');
        await fetchPatientAppointments(appointmentRequest.doctorId!,
            isOnline: true);
        state = state.copyWith(isLoading: false);
        return result;
      } else {
        return await _offlineQueueOp(
          op: OfflineOperation.queueNext,
          request: appointmentRequest,
        );
      }
    } catch (e) {
      debugPrint('QueueNext VM error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Queue Skip ──────────────────────────────────────────────────────────────

  Future<AppointmentResponseModel> queueSkip(
    AppointmentRequestModel appointmentRequest, {
    bool isOnline = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (isOnline) {
        final result = await usecase.queueSkip(appointmentRequest);
        await fetchPatientAppointments(appointmentRequest.doctorId!,
            isOnline: true);
        state = state.copyWith(isLoading: false);
        return result;
      } else {
        return await _offlineQueueOp(
          op: OfflineOperation.queueSkip,
          request: appointmentRequest,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Queue Recall ────────────────────────────────────────────────────────────

  Future<AppointmentResponseModel> queueRecall(
    AppointmentRequestModel appointmentRequest, {
    bool isOnline = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (isOnline) {
        final result = await usecase.queueRecall(appointmentRequest);
        await fetchPatientAppointments(appointmentRequest.doctorId!,
            isOnline: true);
        state = state.copyWith(isLoading: false);
        return result;
      } else {
        return await _offlineQueueOp(
          op: OfflineOperation.queueRecall,
          request: appointmentRequest,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Start / End Session ─────────────────────────────────────────────────────

  Future<AppointmentResponseModel> startSession(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.startSession(appointmentRequest);
      await fetchPatientAppointments(appointmentRequest.doctorId!,
          isOnline: true);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<AppointmentResponseModel> endSession(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.endSession(appointmentRequest);
      await fetchPatientAppointments(appointmentRequest.doctorId!,
          isOnline: true);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Queue Pause Emergency ───────────────────────────────────────────────────

  Future<AppointmentResponseModel> queuePauseEmergency(
    int queueId, {
    bool isOnline = true,
    int? doctorId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (isOnline) {
        final result = await usecase.queuePauseEmergency(queueId);
        final newSet = {...state.emergencyQueueIds, queueId};
        final queues = state.todayQueueResult?.value ?? [];
        state = state.copyWith(
          isLoading: false,
          queueState: QueueState.paused,
          emergencyQueueIds: newSet,
          todayQueueResult: AsyncValue.data(_applyEmergency(queues, newSet)),
        );
        return result;
      } else {
        // Offline emergency pause
        await offlineStore.enqueueEmergencyPause(
            queueId, doctorId ?? queueId);
        await offlineStore.applyOfflineQueueOp(
            OfflineOperation.queuePauseEmergency, queueId, null);

        final newSet = {...state.emergencyQueueIds, queueId};
        final queues = state.todayQueueResult?.value ?? [];
        final pendingCount = await offlineStore.pendingOpsCount();
        state = state.copyWith(
          isLoading: false,
          queueState: QueueState.paused,
          emergencyQueueIds: newSet,
          todayQueueResult: AsyncValue.data(_applyEmergency(queues, newSet)),
          pendingOpsCount: pendingCount,
        );
        return AppointmentResponseModel(success: true, message: 'Saved offline');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Cancel Appointment By Doctor ────────────────────────────────────────────

  Future<AppointmentResponseModel> cancelByDoctor(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.cancelByDoctor(appointmentRequest);
      await fetchPatientAppointments(appointmentRequest.doctorId!,
          isOnline: true);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<List<TodayQueueModel>> getTodayQueue(int doctorId,
      {bool isOnline = true}) async {
    state = state.copyWith(
      todayQueueResult: const AsyncValue.loading(),
      error: null,
    );
    try {
      List<TodayQueueModel> result;
      if (isOnline) {
        result = await usecase.getTodayQueue(doctorId);
        await offlineStore.cacheQueues(result);
      } else {
        result = await offlineStore.getCachedQueues(doctorId);
      }
      state = state.copyWith(todayQueueResult: AsyncValue.data(result));
      return result;
    } catch (e, st) {
      // Fallback to cache on error
      try {
        final cached = await offlineStore.getCachedQueues(doctorId);
        state = state.copyWith(todayQueueResult: AsyncValue.data(cached));
        return cached;
      } catch (_) {
        state = state.copyWith(todayQueueResult: AsyncValue.error(e, st));
        rethrow;
      }
    }
  }

  // ── Sync: flush pending operations after coming back online ─────────────────

  Future<void> syncPendingOps(int doctorId) async {
    final flushed = await offlineStore.flushPendingOps(
      (op, payload) => _executeOp(op, payload),
    );
    if (flushed > 0) {
      debugPrint('[AppointmentVM] Flushed $flushed pending op(s), refreshing.');
      await fetchPatientAppointments(doctorId, isOnline: true);
    }
    final pendingCount = await offlineStore.pendingOpsCount();
    state = state.copyWith(pendingOpsCount: pendingCount);
  }

  Future<AppointmentResponseModel> _executeOp(
    OfflineOperation op,
    Map<String, dynamic> payload,
  ) async {
    switch (op) {
      case OfflineOperation.queueStart:
        return usecase.queueStart(AppointmentRequestModel.fromJson(payload));
      case OfflineOperation.queuePause:
        return usecase.queuePause(AppointmentRequestModel.fromJson(payload));
      case OfflineOperation.queueStop:
        return usecase.queueStop(AppointmentRequestModel.fromJson(payload));
      case OfflineOperation.queueNext:
        return usecase.queueNext(AppointmentRequestModel.fromJson(payload));
      case OfflineOperation.queueSkip:
        return usecase.queueSkip(AppointmentRequestModel.fromJson(payload));
      case OfflineOperation.queueRecall:
        return usecase.queueRecall(AppointmentRequestModel.fromJson(payload));
      case OfflineOperation.queuePauseEmergency:
        final qId = payload['queue_id'] as int;
        return usecase.queuePauseEmergency(qId);
    }
  }

  // ── Offline op helper ───────────────────────────────────────────────────────

  Future<AppointmentResponseModel> _offlineQueueOp({
    required OfflineOperation op,
    required AppointmentRequestModel request,
    QueueState? newQueueState,
  }) async {
    // 1. Persist to pending-ops queue
    await offlineStore.enqueueOp(op, request, queueId: request.queueId);

    // 2. Apply optimistic local mutation
    await offlineStore.applyOfflineQueueOp(
        op, request.queueId, request.appointmentId);

    // 3. Reload UI from cache so optimistic changes are visible
    if (request.doctorId != null) {
      await _loadFromCache(request.doctorId!);
    }

    // 4. Update queue state machine in memory
    if (newQueueState != null) {
      state = state.copyWith(isLoading: false, queueState: newQueueState);
    } else {
      state = state.copyWith(isLoading: false);
    }

    final pendingCount = await offlineStore.pendingOpsCount();
    state = state.copyWith(pendingOpsCount: pendingCount);

    return AppointmentResponseModel(success: true, message: 'Saved offline');
  }
}
