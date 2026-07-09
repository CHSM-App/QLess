import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/database/offline_queue_store.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/available_slots.dart';
import 'package:qless/domain/models/queue_preview_model.dart';

import 'package:qless/core/network/socket_service.dart';
import 'package:qless/domain/usecase/appointment_usecase.dart';

class AppointmentState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final AppointmentResponseModel? availabilityResponse;
  final AppointmentResponseModel? bookingResponse;
  final AppointmentResponseModel? rescheduleResponse;
  final AppointmentResponseModel? cancelResponse;
  final AppointmentResponseModel? queueStatusResponse;
   final Map<int, QueuePreviewResponseModel> queueEstimates;
  final QueuePreviewResponseModel? queuePreviewEstimateResponse;
  final List<MonthSlotData> bookedSlots;
  final AsyncValue<List<AppointmentList>>?  patientAppointmentsList;
  final int? doctorPatientCount;
  final Set<int> offlineDoctors; // doctor IDs whose network is currently down
  // Live queue status per "doctorId_queueId": 'queue_started' | 'queue_paused' |
  // 'queue_paused_emergency' | 'queue_stopped'. Keyed by queue_id (not just
  // doctorId) so a doctor running two simultaneous queues/sessions doesn't have
  // one queue's "live" banner bleed onto the other queue's appointment card.
  final Map<String, String> doctorQueueEvents;
  // Real current_serving per "doctorId_clinicId" from socket events (overrides SP value).
  final Map<String, int> doctorCurrentServing;

  const AppointmentState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.availabilityResponse,
    this.bookingResponse,
    this.rescheduleResponse,
    this.cancelResponse,
    this.queueStatusResponse,
    this.queueEstimates = const {},
    this.queuePreviewEstimateResponse,
    this.bookedSlots = const [],
    this.patientAppointmentsList,
    this.doctorPatientCount,
    this.offlineDoctors = const {},
    this.doctorQueueEvents = const {},
    this.doctorCurrentServing = const {},
  });

  AppointmentState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    bool clearError = false,
    bool clearBookingResponse = false,
    AppointmentResponseModel? availabilityResponse,
    AppointmentResponseModel? bookingResponse,
    AppointmentResponseModel? rescheduleResponse,
    AppointmentResponseModel? cancelResponse,
    AppointmentResponseModel? queueStatusResponse,
  Map<int, QueuePreviewResponseModel>? queueEstimates,
    QueuePreviewResponseModel? queuePreviewEstimateResponse,
    List<MonthSlotData>? bookedSlots,
    AsyncValue<List<AppointmentList>>?  patientAppointmentsList,
    int? doctorPatientCount,
    bool clearDoctorPatientCount = false,
    Set<int>? offlineDoctors,
    Map<String, String>? doctorQueueEvents,
    Map<String, int>? doctorCurrentServing,
  }) {
    return AppointmentState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
      availabilityResponse: availabilityResponse ?? this.availabilityResponse,
      bookingResponse: clearBookingResponse ? null : (bookingResponse ?? this.bookingResponse),
      rescheduleResponse: rescheduleResponse ?? this.rescheduleResponse,
      cancelResponse: cancelResponse ?? this.cancelResponse,
      queueStatusResponse: queueStatusResponse ?? this.queueStatusResponse,
      queueEstimates: queueEstimates ?? this.queueEstimates,
      queuePreviewEstimateResponse:
          queuePreviewEstimateResponse ?? this.queuePreviewEstimateResponse,
      bookedSlots: bookedSlots ?? this.bookedSlots,
      patientAppointmentsList: patientAppointmentsList ?? this.patientAppointmentsList,
      doctorPatientCount: clearDoctorPatientCount
          ? null
          : (doctorPatientCount ?? this.doctorPatientCount),
      offlineDoctors: offlineDoctors ?? this.offlineDoctors,
      doctorQueueEvents: doctorQueueEvents ?? this.doctorQueueEvents,
      doctorCurrentServing: doctorCurrentServing ?? this.doctorCurrentServing,
    );
  }
}

class AppointmentViewmodel extends StateNotifier<AppointmentState> {
  final AppointmentUsecase usecase;
  final OfflineQueueStore offlineStore;
  final SocketService socketService;

  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;

  AppointmentViewmodel(this.usecase, this.offlineStore, this.socketService)
      : super(const AppointmentState());

  void watchClinics(List<int> doctorIds, int patientId) {
    _socketSub?.cancel();
    _statusSub?.cancel();
    debugPrint('[SOCKET] watchClinics called for doctorIds=$doctorIds');

    // Register BEFORE joinClinic so we don't miss the immediate doctor_status
    // reply the backend sends when the doctor is already offline at join time.
    _statusSub = socketService.doctorStatusUpdates.listen((data) {
      debugPrint('[SOCKET] doctor_status received: $data');
      final raw      = data['doctor_id'];
      final doctorId = raw is int ? raw : int.tryParse(raw.toString());
      final online   = data['online'] as bool? ?? true;
      if (doctorId == null) return;
      final updated = Set<int>.from(state.offlineDoctors);
      if (online) { updated.remove(doctorId); } else { updated.add(doctorId); }
      debugPrint('[SOCKET] offlineDoctors updated: $updated');
      state = state.copyWith(offlineDoctors: updated);
    });

    const bannerEvents = {
      'queue_started', 'queue_paused', 'queue_paused_emergency', 'queue_stopped',
    };
    _socketSub = socketService.updates.listen((data) {
      final event = data['event'] as String?;
      final raw   = data['doctor_id'];
      final dId   = raw is int ? raw : int.tryParse(raw.toString());
      if (dId != null) {
        // Capture real current_serving from socket, keyed by "doctorId_clinicId"
        // so a CL001 event never pollutes CL002 patient's NOW circle.
        final rawCs = data['current_serving'];
        final cs = rawCs is int ? rawCs : int.tryParse(rawCs?.toString() ?? '');
        final rawCl = data['clinic_id'];
        final clinicId = rawCl?.toString();
        if (cs != null && cs > 0 && clinicId != null && clinicId.isNotEmpty) {
          final key = '${dId}_$clinicId';
          final csMap = Map<String, int>.from(state.doctorCurrentServing);
          csMap[key] = cs;
          state = state.copyWith(doctorCurrentServing: csMap);
        }
        if (event != null && bannerEvents.contains(event)) {
          final rawQ = data['queue_id'];
          final qId  = rawQ is int ? rawQ : int.tryParse(rawQ?.toString() ?? '');
          if (qId != null) {
            final evMap = Map<String, String>.from(state.doctorQueueEvents);
            evMap['${dId}_$qId'] = event;
            state = state.copyWith(doctorQueueEvents: evMap);
          }
        }
      }
      getPatientAppointments(patientId, silent: true);
    });

    // Join AFTER listeners are set up.
    for (final id in doctorIds) {
      socketService.joinClinic(id);
    }
  }

  void unwatchClinics() {
    _socketSub?.cancel();
    _statusSub?.cancel();
    _socketSub = null;
    _statusSub = null;
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  // Future<void> getAppointmentAvailability(
  //   AppointmentRequestModel appointmentRequest,
  // ) async {
  //   state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
  //   try {
  //     final result = await usecase.getAppointmentAvailability(appointmentRequest);
  //     state = state.copyWith(
  //       isLoading: false,
  //       isSuccess: true,
  //       availabilityResponse: result,
  //     );
  //   } catch (e) {
  //     state = state.copyWith(isLoading: false, error: _extractError(e));
  //   }
  // }


  Future<void> getPatientAppointments(int familyId, {bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(
        patientAppointmentsList: const AsyncValue.loading(),
        error: null,
      );
    }
    try {
      final result = await usecase.getPatientAppointments(familyId);
      // Cache so the list (upcoming/past) still renders offline.
      try {
        await offlineStore.cachePatientAppointments(familyId, result);
      } catch (_) {}
      state = state.copyWith(patientAppointmentsList: AsyncValue.data(result));
    } catch (e) {
      // Network down — fall back to the cached list instead of an error state
      // (which the screens render as a hard "no internet" / empty view).
      try {
        final cached =
            await offlineStore.getCachedPatientAppointments(familyId);
        state =
            state.copyWith(patientAppointmentsList: AsyncValue.data(cached));
      } catch (cacheErr) {
        debugPrint('[PatientApptVM] cache load failed: $cacheErr');
        state = state.copyWith(
            patientAppointmentsList: const AsyncValue.data([]));
      }
    }
  }

  Future<void> bookAppointment(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false, clearBookingResponse: true);
    try {
      final result = await usecase.bookAppointment(appointmentRequest);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        bookingResponse: result,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }

  Future<void> rescheduleAppointment(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      final result = await usecase.rescheduleAppointment(appointmentRequest);
      if (result.success == false) {
        state = state.copyWith(
          isLoading: false,
          error: result.message ?? 'Reschedule failed',
          rescheduleResponse: result,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isSuccess: true,
          rescheduleResponse: result,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }

  Future<void> cancelAppointment(int appointmentId) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      final result = await usecase.cancelAppointment(appointmentId);
      if (result.success == false) {
        state = state.copyWith(
          isLoading: false,
          error: result.message ?? 'Cancellation failed',
          cancelResponse: result,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isSuccess: true,
          cancelResponse: result,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }

  Future<bool> markArrived(int appointmentId, int patientId, int familyId) async {
    try {
      final result = await usecase.markArrived(
        AppointmentRequestModel(appointmentId: appointmentId, patientId: patientId),
      );
      if (result.success == true) {
        await getPatientAppointments(familyId, silent: true);
      }
      return result.success == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateQueueStatus(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      final result = await usecase.updateQueueStatus(appointmentRequest);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        queueStatusResponse: result,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }

  Future<void> getBookedSlots(int doctorId, String clinicId) async {
    try {
      final result = await usecase.getBookedSlots(doctorId, clinicId);
      state = state.copyWith(bookedSlots: result);
    } catch (_) {
      // Non-critical — slots just won't be grayed out
    }
  }

  Future<void> fetchDoctorPatientCount(int doctorId, {String? clinicId}) async {
    // Reset so a new doctor's profile shows '--' instead of the previous
    // doctor's count until this fetch resolves.
    state = state.copyWith(clearDoctorPatientCount: true);
    try {
      final result = await usecase.fetchPatientAppointments(doctorId, clinicId: clinicId);
      final count = result
          .where((a) => a.status?.toLowerCase() == 'completed')
          .length;
      state = state.copyWith(doctorPatientCount: count);
    } catch (_) {
      // Non-critical — count just won't show
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// Wipe all appointment state. Call on logout so the next patient starts
  /// clean — otherwise the previous patient's cached `patientAppointmentsList`
  /// survives in memory and the home screen's first build fires the "Today's
  /// Appointment" popup with the previous patient's appointment.
  void reset() => state = const AppointmentState();

  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return e.message ?? 'Request failed';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }


  Future<void> queuePreviewEstimate(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      final result = await usecase.queuePreviewEstimate(appointmentRequest);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        queuePreviewEstimateResponse: result,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }

  
  // Future<void> queueEstimate(
  //   AppointmentRequestModel appointmentRequest,
  // ) async {
  //   state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
  //   try {
  //     final result = await usecase.queueEstimate(appointmentRequest);
  //     state = state.copyWith(
  //       isLoading: false,
  //       isSuccess: true,
  //       queueEstimateResponse: result,
  //     );
  //   } catch (e) {
  //     state = state.copyWith(isLoading: false, error: _extractError(e));
  //   }
  // }


  Future<void> queueEstimate(
  AppointmentRequestModel appointmentRequest,
) async {
  try {
    // final result = await usecase.queueEstimate(appointmentRequest);

    // final appointmentId = appointmentRequest.appointmentId;

    // if (appointmentId == null) return;

    // state = state.copyWith(
    //   queueEstimates: {
    //     ...state.queueEstimates,
    //     appointmentId: result,
    //   },
    // );

  } catch (e) {
    state = state.copyWith(error: _extractError(e));
  }
}
}
