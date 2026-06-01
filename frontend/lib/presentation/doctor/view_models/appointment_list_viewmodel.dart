import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const AppointmentListState({
    this.isLoading = false,
    this.error,
    this.patientAppointmentsList = const AsyncValue.data([]),
    this.queueState = QueueState.idle,
    this.todayQueueResult = const AsyncValue.data([]),
    this.doctorPatientCount,
    this.emergencyQueueIds = const {},
  });

  AppointmentListState copyWith({
    bool? isLoading,
    String? error,
    AsyncValue<List<AppointmentList>>? patientAppointmentsList,
    AsyncValue<List<TodayQueueModel>>? todayQueueResult,
    QueueState? queueState,
    int? doctorPatientCount,
    Set<int>? emergencyQueueIds,
  }) {
    return AppointmentListState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      patientAppointmentsList: patientAppointmentsList ?? this.patientAppointmentsList,
      queueState: queueState ?? this.queueState,
      todayQueueResult: todayQueueResult ?? this.todayQueueResult,
      doctorPatientCount: doctorPatientCount ?? this.doctorPatientCount,
      emergencyQueueIds: emergencyQueueIds ?? this.emergencyQueueIds,
    );
  }
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

class AppointmentListViewmodel extends StateNotifier<AppointmentListState> {
  final AppointmentUsecase usecase;

  AppointmentListViewmodel(this.usecase) : super(const AppointmentListState());

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<void> fetchPatientAppointments(int doctorId) async {
    state = state.copyWith(
      patientAppointmentsList: const AsyncValue.loading(),
      error: null,
    );
    try {
      final result = await usecase.fetchPatientAppointments(doctorId);
      // Derive queue state from backend data so it survives app restarts
      final derivedQueueState = _deriveQueueState(result.isNotEmpty ? result.first.queueStatus : null);

      // Also fetch today's queue sessions to get queue_id per session
      List<TodayQueueModel> todayQueues = [];
      try {
        todayQueues = await usecase.getTodayQueue(doctorId);
      } catch (_) {}

      final emIds = state.emergencyQueueIds;
      state = state.copyWith(
        patientAppointmentsList: AsyncValue.data(result),
        queueState: _adjustForEmergency(derivedQueueState, result, emIds),
        todayQueueResult: AsyncValue.data(_applyEmergency(todayQueues, emIds)),
      );
    } catch (e, st) {
      state = state.copyWith(patientAppointmentsList: AsyncValue.error(e, st));
    }
  }

  QueueState _deriveQueueState(int? queueStatus) {
    switch (queueStatus) {
      case 1: return QueueState.running;  // QUEUE_START
      case 2: return QueueState.paused;   // QUEUE_PAUSE
      case 3: return QueueState.stopped;  // QUEUE_STOP
      default: return QueueState.idle;    // no queue row yet
    }
  }

  // Force emergency-paused queues to display as "paused" (status 2) so the
  // card shows the Resume control. The backend's own emergency status maps to
  // idle otherwise, which would wrongly show "Start".
  List<TodayQueueModel> _applyEmergency(
      List<TodayQueueModel> queues, Set<int> emIds) {
    if (emIds.isEmpty) return queues;
    return queues
        .map((q) => (q.queueId != null && emIds.contains(q.queueId))
            ? q.copyWith(queueStatus: 2)
            : q)
        .toList();
  }

  // Keep the global queue state in sync: a backend "idle" that's really an
  // emergency-paused queue should read as paused.
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

  Future<void> fetchDoctorPatientCount(int doctorId) async {
    try {
      final result = await usecase.fetchPatientAppointments(doctorId);
      final count = result
          .where((a) => a.status?.toLowerCase() == 'completed')
          .length;
      state = state.copyWith(doctorPatientCount: count);
    } catch (_) {
      // Non-critical — count just won't show
    }
  }

  // ── Queue Start ────────────────────────────────────────────────────────────

  Future<AppointmentResponseModel> queueStart(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.queueStart(appointmentRequest);
      // Resuming clears any emergency-pause flag for this queue.
      _clearEmergency(appointmentRequest.queueId);
      await fetchPatientAppointments(appointmentRequest.doctorId!);
      state = state.copyWith(isLoading: false, queueState: QueueState.running);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Queue Pause ────────────────────────────────────────────────────────────

  Future<AppointmentResponseModel> queuePause(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.queuePause(appointmentRequest);
      // A normal pause supersedes an emergency pause on the same queue.
      _clearEmergency(appointmentRequest.queueId);
      await fetchPatientAppointments(appointmentRequest.doctorId!);
      state = state.copyWith(isLoading: false, queueState: QueueState.paused);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Queue Stop ─────────────────────────────────────────────────────────────

  Future<AppointmentResponseModel> queueStop(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.queueStop(appointmentRequest);
      _clearEmergency(appointmentRequest.queueId);
      await fetchPatientAppointments(appointmentRequest.doctorId!);
      state = state.copyWith(isLoading: false, queueState: QueueState.stopped);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Queue Next (Mark Complete) ─────────────────────────────────────────────

  Future<AppointmentResponseModel> queueNext(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      debugPrint('QueueNext VM request: ${appointmentRequest.toJson()}');
      final result = await usecase.queueNext(appointmentRequest);
      debugPrint('QueueNext VM response: ${result.toJson()}');
      await fetchPatientAppointments(appointmentRequest.doctorId!);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      debugPrint('QueueNext VM error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Queue Skip ─────────────────────────────────────────────────────────────

  Future<AppointmentResponseModel> queueSkip(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.queueSkip(appointmentRequest);
      await fetchPatientAppointments(appointmentRequest.doctorId!);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Queue Recall (attend a skipped patient) ────────────────────────────────

  Future<AppointmentResponseModel> queueRecall(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.queueRecall(appointmentRequest);
      await fetchPatientAppointments(appointmentRequest.doctorId!);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

Future<AppointmentResponseModel> startSession(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.startSession(appointmentRequest);
      await fetchPatientAppointments(appointmentRequest.doctorId!);
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
      await fetchPatientAppointments(appointmentRequest.doctorId!);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
    }

  // ── Queue Pause Emergency ──────────────────────────────────────────────────

  Future<AppointmentResponseModel> queuePauseEmergency(int queueId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.queuePauseEmergency(queueId);
      // Remember this queue as emergency-paused and force its card to read as
      // paused so the Resume control shows (mirrors a normal pause).
      final newSet = {...state.emergencyQueueIds, queueId};
      final queues = state.todayQueueResult?.value ?? [];
      state = state.copyWith(
        isLoading: false,
        queueState: QueueState.paused,
        emergencyQueueIds: newSet,
        todayQueueResult: AsyncValue.data(_applyEmergency(queues, newSet)),
      );
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Cancel Appointment By Doctor ───────────────────────────────────────────

  Future<AppointmentResponseModel> cancelByDoctor(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.cancelByDoctor(appointmentRequest);
      await fetchPatientAppointments(appointmentRequest.doctorId!);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<List<TodayQueueModel>> getTodayQueue(int doctorId) async {
    state = state.copyWith(
      todayQueueResult: const AsyncValue.loading(),
      error: null,
    );
    try {
      final result = await usecase.getTodayQueue(doctorId);
      state = state.copyWith(
        todayQueueResult: AsyncValue.data(result),
      );
      return result;
    } catch (e, st) {
      state = state.copyWith(todayQueueResult: AsyncValue.error(e, st));
      rethrow;
    }
  }

}
