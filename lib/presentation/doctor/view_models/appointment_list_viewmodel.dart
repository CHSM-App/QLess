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

  const AppointmentListState({
    this.isLoading = false,
    this.error,
    this.patientAppointmentsList = const AsyncValue.data([]),
    this.queueState = QueueState.idle,
    this.todayQueueResult = const AsyncValue.data([]),
  });

  AppointmentListState copyWith({
    bool? isLoading,
    String? error,
    AsyncValue<List<AppointmentList>>? patientAppointmentsList,
    AsyncValue<List<TodayQueueModel>>? todayQueueResult,
    QueueState? queueState,
  }) {
    return AppointmentListState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      patientAppointmentsList: patientAppointmentsList ?? this.patientAppointmentsList,
      queueState: queueState ?? this.queueState,
      todayQueueResult: todayQueueResult ?? this.todayQueueResult,
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

      state = state.copyWith(
        patientAppointmentsList: AsyncValue.data(result),
        queueState: derivedQueueState,
        todayQueueResult: AsyncValue.data(todayQueues),
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

  // ── Queue Start ────────────────────────────────────────────────────────────

  Future<AppointmentResponseModel> queueStart(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await usecase.queueStart(appointmentRequest);
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
      state = state.copyWith(isLoading: false, queueState: QueueState.paused);
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
