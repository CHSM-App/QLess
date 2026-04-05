import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/domain/usecase/family_usecase.dart';
import 'package:qless/domain/usecase/patient_login_usecase.dart';

class FamilyState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
 
  final AsyncValue<List<FamilyMember>> allfamilyMembers;
  
  const FamilyState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  
    this.allfamilyMembers = const AsyncValue.data([]),
  });

  FamilyState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    bool clearError = false,
   
    AsyncValue<List<FamilyMember>>? allfamilyMembers,
  }) {
    return FamilyState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
      
      allfamilyMembers: allfamilyMembers ?? this.allfamilyMembers,
    );
  }
}

class FamilyViewmodel extends StateNotifier<FamilyState> {
  final FamilyUsecase usecase;

  FamilyViewmodel(this.usecase) : super(const FamilyState()) ;
  

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

  Future<void> fetchAllFamilyMembers(int familyId) async {
    state = state.copyWith(
      allfamilyMembers: const AsyncValue.loading(),
      error: null,
    );
    try {
      final result = await usecase.fetchFamilyMembers(familyId);
      state = state.copyWith(allfamilyMembers: AsyncValue.data(result));
    } catch (e, st) {
      state = state.copyWith(allfamilyMembers: AsyncValue.error(e, st));
    }
  }

  Future<String?> deleteFamilyMember(int memberId) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      await usecase.deleteFamilyMember(memberId);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return 'Member deleted successfully';
    } catch (e) {
      final message = _extractMessage(e);
      final treatAsSuccess =
          message.toLowerCase().contains('operation completed');
      state = state.copyWith(
        isLoading: false,
        isSuccess: treatAsSuccess,
        error: treatAsSuccess ? null : message,
      );
      return message;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  String _extractMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (data is String && data.trim().isNotEmpty) return data;
      return e.message ?? 'Request failed';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
