import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/domain/usecase/patient_login_usecase.dart';

class PatientLoginState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final int? patientId;
  final String? name;
  final String? mobileNo;
  final String? email;
  final String? roleId;
  final String? token;

  final AsyncValue<List<Patients>> patientPhoneCheck;
  const PatientLoginState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.name,
    this.mobileNo,
    this.email,
    this.roleId,
    this.token,
    this.patientId,
    this.patientPhoneCheck = const AsyncValue.data([]),
  });

  PatientLoginState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    bool clearError = false,
    String? name,
    String? mobileNo,
    String? email,
    String? roleId,
    String? token,
    int? patientId,

    AsyncValue<List<Patients>>? patientPhoneCheck,
  }) {
    return PatientLoginState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      mobileNo: mobileNo ?? this.mobileNo,
      email: email ?? this.email,
      roleId: roleId ?? this.roleId,
      token: token ?? this.token,
      patientPhoneCheck: patientPhoneCheck ?? this.patientPhoneCheck,
    );
  }
}

class PatientLoginViewmodel extends StateNotifier<PatientLoginState> {
  final PatientLoginUsecase usecase;

  PatientLoginViewmodel(this.usecase) : super(const PatientLoginState()) {
    loadFromStoragePatient();
  }

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

  Future<void> loadFromStoragePatient() async {
    final name = await TokenStorage.getValue('name');
    final mobileNo = await TokenStorage.getValue('mobile_no');
    final email = await TokenStorage.getValue('email');
    final roleId = await TokenStorage.getValue('role_id');

    final token = await TokenStorage.getValue('token');
    final patientIdStr = await TokenStorage.getValue('patient_id');
    final patientId = int.tryParse(patientIdStr ?? '0') ?? 0;

    state = state.copyWith(
      patientId: patientId,
      name: name,
      mobileNo: mobileNo,
      email: email,
      roleId: roleId,
      token: token,

      patientPhoneCheck: AsyncValue.data([
        Patients(
          patientId: patientId,
          name: name,
          mobileNo: mobileNo,
          email: email,
          roleId: roleId != null ? int.tryParse(roleId) : null,
          Token: token,
        ),
      ]),
    );
  }

  Future<void> checkPhonePatient(String mobileNo) async {
    state = state.copyWith(
      patientPhoneCheck: const AsyncValue.loading(),
      error: null,
    );
    try {
      final result = await usecase.checkPhonePatient(mobileNo);
      state = state.copyWith(patientPhoneCheck: AsyncValue.data(result));
    } catch (e, st) {
      debugPrint('PatientLoginViewmodel.checkPhonePatient error: $e');
      debugPrint('$st');
      state = state.copyWith(
        patientPhoneCheck: AsyncValue.error(e, st),
        error: e.toString(),
      );
    }
  }

    Future<void> addFamilyMember(FamilyMember member) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      await usecase.addFamilyMember(member);
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
