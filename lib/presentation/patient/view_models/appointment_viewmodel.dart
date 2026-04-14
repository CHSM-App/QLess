import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/available_slots.dart';
import 'package:qless/domain/models/queue_preview_model.dart';

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
  });

  AppointmentState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    bool clearError = false,
    AppointmentResponseModel? availabilityResponse,
    AppointmentResponseModel? bookingResponse,
    AppointmentResponseModel? rescheduleResponse,
    AppointmentResponseModel? cancelResponse,
    AppointmentResponseModel? queueStatusResponse,
  Map<int, QueuePreviewResponseModel>? queueEstimates,
    QueuePreviewResponseModel? queuePreviewEstimateResponse,
    List<MonthSlotData>? bookedSlots,
    AsyncValue<List<AppointmentList>>?  patientAppointmentsList,
  }) {
    return AppointmentState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
      availabilityResponse: availabilityResponse ?? this.availabilityResponse,
      bookingResponse: bookingResponse ?? this.bookingResponse,
      rescheduleResponse: rescheduleResponse ?? this.rescheduleResponse,
      cancelResponse: cancelResponse ?? this.cancelResponse,
      queueStatusResponse: queueStatusResponse ?? this.queueStatusResponse,
      queueEstimates: queueEstimates ?? this.queueEstimates,
      
      queuePreviewEstimateResponse:
          queuePreviewEstimateResponse ?? this.queuePreviewEstimateResponse,
      bookedSlots: bookedSlots ?? this.bookedSlots,
      patientAppointmentsList: patientAppointmentsList ?? this.patientAppointmentsList,
    );
  }
}

class AppointmentViewmodel extends StateNotifier<AppointmentState> {
  final AppointmentUsecase usecase;

  AppointmentViewmodel(this.usecase) : super(const AppointmentState());

  Future<void> getAppointmentAvailability(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      final result = await usecase.getAppointmentAvailability(appointmentRequest);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        availabilityResponse: result,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }


  Future<void> getPatientAppointments(int familyId) async {
    state = state.copyWith(
      patientAppointmentsList: const AsyncValue.loading(),
      error: null,
    );
    try {
      final result = await usecase.getPatientAppointments(familyId);
      state = state.copyWith(patientAppointmentsList: AsyncValue.data(result));
    } catch (e, st) {
      state = state.copyWith(patientAppointmentsList: AsyncValue.error(e, st));
    }
  }

  Future<void> bookAppointment(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
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

  Future<void> getBookedSlots(int doctorId) async {
    try {
      final result = await usecase.getBookedSlots(doctorId);
      state = state.copyWith(bookedSlots: result);
    } catch (_) {
      // Non-critical — slots just won't be grayed out
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

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
    final result = await usecase.queueEstimate(appointmentRequest);

    final appointmentId = appointmentRequest.appointmentId;

    if (appointmentId == null) return;

    state = state.copyWith(
      queueEstimates: {
        ...state.queueEstimates,
        appointmentId: result,
      },
    );

  } catch (e) {
    state = state.copyWith(error: _extractError(e));
  }
}
}
