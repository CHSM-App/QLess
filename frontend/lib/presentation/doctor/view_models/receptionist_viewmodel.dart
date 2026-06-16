import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/domain/models/receptionist_model.dart';
import 'package:qless/domain/usecase/receptionist_usecase.dart';

class ReceptionistLoginState {
  final bool isLoading;
  final String? error;
  final int? recepId;
  final String? name;
  final String? mobileNo;
  final String? email;
  final String? address;
  final int? genderId;
  final int? roleId;
  final String? token;
  final String? clinicId;
  final int? doctorId;
  final AsyncValue<List<ReceptionistApiModel>> phoneCheckResult;
  final AsyncValue<List<ReceptionistApiModel>> receptionistList;

  const ReceptionistLoginState({
    this.isLoading = false,
    this.error,
    this.recepId,
    this.name,
    this.mobileNo,
    this.email,
    this.address,
    this.genderId,
    this.roleId,
    this.token,
    this.clinicId,
    this.doctorId,
    this.phoneCheckResult = const AsyncValue.data([]),
    this.receptionistList = const AsyncValue.data([]),
  });

  ReceptionistLoginState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? recepId,
    String? name,
    String? mobileNo,
    String? email,
    String? address,
    int? genderId,
    int? roleId,
    String? token,
    String? clinicId,
    int? doctorId,
    AsyncValue<List<ReceptionistApiModel>>? phoneCheckResult,
    AsyncValue<List<ReceptionistApiModel>>? receptionistList,
  }) {
    return ReceptionistLoginState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      recepId: recepId ?? this.recepId,
      name: name ?? this.name,
      mobileNo: mobileNo ?? this.mobileNo,
      email: email ?? this.email,
      address: address ?? this.address,
      genderId: genderId ?? this.genderId,
      roleId: roleId ?? this.roleId,
      token: token ?? this.token,
      clinicId: clinicId ?? this.clinicId,
      doctorId: doctorId ?? this.doctorId,
      phoneCheckResult: phoneCheckResult ?? this.phoneCheckResult,
      receptionistList: receptionistList ?? this.receptionistList,
    );
  }
}

class ReceptionistLoginViewmodel
    extends StateNotifier<ReceptionistLoginState> {
  final ReceptionistUsecase usecase;

  ReceptionistLoginViewmodel(this.usecase)
      : super(const ReceptionistLoginState()) {
    loadFromStorage();
  }

  Future<void> loadFromStorage() async {
    final name     = await TokenStorage.getValue('recep_name') ?? await TokenStorage.getValue('name');
    final mobileNo = await TokenStorage.getValue('mobile_no');
    final email    = await TokenStorage.getValue('recep_email') ?? await TokenStorage.getValue('email');
    final address  = await TokenStorage.getValue('recep_address');
    final roleIdStr = await TokenStorage.getValue('role_id');
    final genderIdStr = await TokenStorage.getValue('recep_gender_id');
    final token    = await TokenStorage.getValue('token');
    final recepIdStr = await TokenStorage.getValue('recep_id');
    final clinicId = await TokenStorage.getValue('clinic_id');
    final doctorIdStr = await TokenStorage.getValue('recep_doctor_id');

    final recepId  = int.tryParse(recepIdStr ?? '') ?? 0;
    final roleId   = int.tryParse(roleIdStr ?? '');
    final doctorId = int.tryParse(doctorIdStr ?? '');
    final genderId = int.tryParse(genderIdStr ?? '');

    final hasFullDetails = state.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );

    state = state.copyWith(
      recepId: recepId,
      name: name,
      mobileNo: mobileNo,
      email: email,
      address: address,
      genderId: genderId,
      roleId: roleId,
      token: token,
      clinicId: clinicId,
      doctorId: doctorId,
      phoneCheckResult: hasFullDetails
          ? state.phoneCheckResult
          : AsyncValue.data([
              ReceptionistApiModel(
                recepId: recepId,
                name: name,
                mobileNo: mobileNo,
                email: email,
                address: address,
                genderId: genderId,
                roleId: roleId,
                Token: token,
                clinicId: clinicId,
              ),
            ]),
    );
  }

  Future<void> checkPhoneReceptionist(String mobileNo) async {
    final hadData = state.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );
    state = state.copyWith(
      phoneCheckResult:
          hadData ? state.phoneCheckResult : const AsyncValue.loading(),
      clearError: true,
    );
    try {
      final result = await usecase.checkPhoneReceptionist(mobileNo);
      if (result.isNotEmpty) {
        final r = result.first;
        state = state.copyWith(
          recepId: r.recepId,
          name: r.name,
          mobileNo: r.mobileNo,
          email: r.email,
          address: r.address,
          genderId: r.genderId,
          roleId: r.roleId,
          token: r.Token,
          clinicId: r.clinicId?.toString(),
          doctorId: r.doctorId,
          phoneCheckResult: AsyncValue.data(result),
        );
        if (r.name != null) await TokenStorage.saveValue('recep_name', r.name!);
        if (r.mobileNo != null) await TokenStorage.saveValue('mobile_no', r.mobileNo!);
        if (r.email != null) await TokenStorage.saveValue('recep_email', r.email!);
        if (r.address != null) await TokenStorage.saveValue('recep_address', r.address!);
        if (r.genderId != null) await TokenStorage.saveValue('recep_gender_id', r.genderId.toString());
      } else {
        state = state.copyWith(phoneCheckResult: AsyncValue.data(result));
      }
    } catch (e, st) {
      state = state.copyWith(
        phoneCheckResult:
            hadData ? state.phoneCheckResult : AsyncValue.error(e, st),
        error: e.toString(),
      );
    }
  }

  Future<List<ReceptionistApiModel>> mobileExistReceptionist(
      String mobileNo) async {
    try {
      return await usecase.mobileExistReceptionist(mobileNo);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  Future<List<ReceptionistApiModel>> fetchReceptionistList(String clinicId) async {
    state = state.copyWith(
      receptionistList: const AsyncValue.loading(),
      clearError: true,
    );
    try {
      final result = await usecase.fetchReceptionistList(clinicId);
      state = state.copyWith(receptionistList: AsyncValue.data(result));
      return result;
    } catch (e, st) {
      state = state.copyWith(
        receptionistList: AsyncValue.error(e, st),
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return [];
    }
  }

  Future<void> addReceptionist(ReceptionistApiModel receptionist,
      {File? image}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await usecase.addReceptionist(receptionist, image: image);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> deleteReceptionist(int recepId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await usecase.deleteReceptionist(recepId);
      final updatedList = state.receptionistList.maybeWhen(
        data: (list) => list.where((r) => r.recepId != recepId).toList(),
        orElse: () => null,
      );
      state = state.copyWith(
        isLoading: false,
        receptionistList: updatedList == null
            ? state.receptionistList
            : AsyncValue.data(updatedList),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void setName(String name) {
    state = state.copyWith(name: name);
    TokenStorage.saveValue('recep_name', name);
  }

  Future<void> setProfileFromCheck(ReceptionistApiModel r) async {
    state = state.copyWith(
      recepId:  r.recepId,
      name:     r.name,
      mobileNo: r.mobileNo,
      email:    r.email,
      address:  r.address,
      genderId: r.genderId,
      roleId:   r.roleId,
      token:    r.Token,
      clinicId: r.clinicId,
      doctorId: r.doctorId,
    );
    if (r.recepId  != null) await TokenStorage.saveValue('recep_id',       r.recepId.toString());
    if (r.name     != null) await TokenStorage.saveValue('recep_name',     r.name!);
    if (r.mobileNo != null) await TokenStorage.saveValue('mobile_no',      r.mobileNo!);
    if (r.email    != null) await TokenStorage.saveValue('recep_email',     r.email!);
    if (r.address  != null) await TokenStorage.saveValue('recep_address',  r.address!);
    if (r.genderId != null) await TokenStorage.saveValue('recep_gender_id', r.genderId.toString());
    if (r.clinicId != null) await TokenStorage.saveValue('recep_clinic_id', r.clinicId!);
    if (r.doctorId != null) await TokenStorage.saveValue('recep_doctor_id', r.doctorId.toString());
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    state = const ReceptionistLoginState();
  }
}
