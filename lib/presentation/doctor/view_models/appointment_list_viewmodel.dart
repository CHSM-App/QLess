
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/usecase/appointment_usecase.dart';


class AppointmentListState {
  final bool isLoading;
  final String? error;
final AsyncValue<List<AppointmentList>> patientAppointmentsList;



  const AppointmentListState({
    this.isLoading = false,
    this.error,
    this.patientAppointmentsList = const AsyncValue.data([]),
  


  });

  AppointmentListState copyWith({
    bool? isLoading,
    String? error,
  AsyncValue<List<AppointmentList>>? patientAppointmentsList,


  }) {
    return AppointmentListState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      patientAppointmentsList: patientAppointmentsList ?? this.patientAppointmentsList,

    );
  }
}

class AppointmentListViewmodel extends StateNotifier<AppointmentListState> {
  final AppointmentUsecase usecase;
  AppointmentListViewmodel(this.usecase) : super(const AppointmentListState()) ;


  Future<void> fetchPatientAppointments(int doctorId) async {
    state = state.copyWith(
      patientAppointmentsList: const AsyncValue.loading(),
      error: null,
    );
    try {
      final result = await usecase.fetchPatientAppointments(doctorId);
      state = state.copyWith(patientAppointmentsList: AsyncValue.data(result));
    } catch (e, st) {
      state = state.copyWith(patientAppointmentsList: AsyncValue.error(e, st));
    }
  }

  Future<AppointmentResponseModel> queueNext(
    AppointmentRequestModel appointmentRequest,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      debugPrint('QueueNext VM request: ${appointmentRequest.toJson()}');
      final result = await usecase.queueNext(appointmentRequest);
      debugPrint('QueueNext VM response: ${result.toJson()}');
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      debugPrint('QueueNext VM error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

}
