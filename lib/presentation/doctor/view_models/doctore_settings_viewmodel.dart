

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/domain/usecase/doctor_settings_usecase.dart';

class DoctorSettingsState{
  final bool isLoading;
  final String errorMessage;
  final DoctorScheduleModel? doctorSchedule;

  const DoctorSettingsState({
    this.isLoading = false,
    this.errorMessage = '',
    this.doctorSchedule = null,
  });


  DoctorSettingsState copyWith({
    bool? isLoading,
    String? errorMessage,
    DoctorScheduleModel? doctorSchedule,
  }) {
    return DoctorSettingsState(
      doctorSchedule: doctorSchedule ?? this.doctorSchedule,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}


class DoctorSettingsViewModel extends StateNotifier<DoctorSettingsState> {
  final DoctorSettingsUsecase doctorSettingsUsecase;

  DoctorSettingsViewModel(this.doctorSettingsUsecase)
      : super(const DoctorSettingsState());

  Future<void> saveDoctorSchedule(DoctorScheduleModel doctorSchedule) async {
    state = state.copyWith(isLoading: true, errorMessage: '');
    try {
      final result =await doctorSettingsUsecase.saveDoctorSchedule(doctorSchedule);
      debugPrint('Doctor schedule saved successfully: ${result['error']}');
    } catch (e) {
      print('Error saving doctor schedule: $e');
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> getDoctorSchedule(int doctorId) async {
    state = state.copyWith(isLoading: true, errorMessage: '');
    try {
      final schedule = await doctorSettingsUsecase.getDoctorSchedule(doctorId);
      state = state.copyWith(doctorSchedule: schedule);
    } catch (e) {
      print('Error fetching doctor schedule: $e');
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}



