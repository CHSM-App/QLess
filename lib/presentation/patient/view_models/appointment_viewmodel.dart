import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/available_slots.dart';
import 'package:qless/domain/usecase/appointment_usecase.dart';

class AppointmentState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final AppointmentResponseModel? availabilityResponse;
  final AppointmentResponseModel? bookingResponse;
  final AppointmentResponseModel? cancelResponse;
  final AppointmentResponseModel? queueStatusResponse;
  final List<MonthSlotData> bookedSlots;

  const AppointmentState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.availabilityResponse,
    this.bookingResponse,
    this.cancelResponse,
    this.queueStatusResponse,
    this.bookedSlots = const [],
  });

  AppointmentState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    bool clearError = false,
    AppointmentResponseModel? availabilityResponse,
    AppointmentResponseModel? bookingResponse,
    AppointmentResponseModel? cancelResponse,
    AppointmentResponseModel? queueStatusResponse,
    List<MonthSlotData>? bookedSlots,
  }) {
    return AppointmentState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
      availabilityResponse: availabilityResponse ?? this.availabilityResponse,
      bookingResponse: bookingResponse ?? this.bookingResponse,
      cancelResponse: cancelResponse ?? this.cancelResponse,
      queueStatusResponse: queueStatusResponse ?? this.queueStatusResponse,
      bookedSlots: bookedSlots ?? this.bookedSlots,
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

  Future<void> cancelAppointment(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      final result = await usecase.cancelAppointment(appointmentRequest);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        cancelResponse: result,
      );
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
}
