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
  final int? roleId;
  final String? token;
  final String? clinicId;
  final AsyncValue<List<ReceptionistApiModel>> phoneCheckResult;
  final AsyncValue<List<ReceptionistApiModel>> receptionistList;

  const ReceptionistLoginState({
    this.isLoading = false,
    this.error,
    this.recepId,
    this.name,
    this.mobileNo,
    this.email,
    this.roleId,
    this.token,
    this.clinicId,
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
    int? roleId,
    String? token,
    String? clinicId,
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
      roleId: roleId ?? this.roleId,
      token: token ?? this.token,
      clinicId: clinicId ?? this.clinicId,
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
    final name     = await TokenStorage.getValue('name');
    final mobileNo = await TokenStorage.getValue('mobile_no');
    final email    = await TokenStorage.getValue('email');
    final roleIdStr = await TokenStorage.getValue('role_id');
    final token    = await TokenStorage.getValue('token');
    final recepIdStr = await TokenStorage.getValue('recep_id');
    final clinicId = await TokenStorage.getValue('clinic_id');

    final recepId  = int.tryParse(recepIdStr ?? '') ?? 0;
    final roleId   = int.tryParse(roleIdStr ?? '');

    final hasFullDetails = state.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );

    state = state.copyWith(
      recepId: recepId,
      name: name,
      mobileNo: mobileNo,
      email: email,
      roleId: roleId,
      token: token,
      clinicId: clinicId,
      phoneCheckResult: hasFullDetails
          ? state.phoneCheckResult
          : AsyncValue.data([
              ReceptionistApiModel(
                recepId: recepId,
                name: name,
                mobileNo: mobileNo,
                email: email,
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
          roleId: r.roleId,
          token: r.Token,
          clinicId: r.clinicId?.toString(),
          phoneCheckResult: AsyncValue.data(result),
        );
        if (r.name != null) await TokenStorage.saveValue('name', r.name!);
        if (r.mobileNo != null) await TokenStorage.saveValue('mobile_no', r.mobileNo!);
        if (r.email != null) await TokenStorage.saveValue('email', r.email!);
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

  Future<void> logout() async {
    await TokenStorage.clear();
    state = const ReceptionistLoginState();
  }
}
