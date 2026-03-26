// lib/viewmodels/patient_login_viewmodel.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/domain/usecase/patient_login_usecase.dart';

class PatientLoginState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const PatientLoginState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  PatientLoginState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return PatientLoginState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class PatientLoginViewmodel extends StateNotifier<PatientLoginState> {
  final PatientLoginUsecase usecase;

  PatientLoginViewmodel(this.usecase) : super(const PatientLoginState());

  Future<void> addPatient(Patients patient) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      await usecase.addPatient(patient);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}