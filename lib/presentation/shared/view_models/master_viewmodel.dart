import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/master_data.dart';
import 'package:qless/domain/usecase/master_usecase.dart';


@immutable
class MasterState {
  final bool isLoading;
  final Map<String, dynamic>? data;
  final String? error;
  final AsyncValue<List<MasterData>> fetchGender;
  final AsyncValue<List<MasterData>> fetchRelation;
  final AsyncValue<List<MasterData>> fetchBloodGroup;


  const MasterState({
    this.isLoading = false,
    this.data,
    this.error,
  
    this.fetchGender = const AsyncValue.loading(),
    this.fetchBloodGroup = const AsyncValue.loading(),
    this.fetchRelation = const AsyncValue.loading(),

  });

  MasterState copyWith({

    bool? isLoading,
    Map<String, dynamic>? data,
    String? error,
    bool clearError = false,
    bool clearData = false,
    AsyncValue<List<MasterData>>? fetchGender,
    AsyncValue<List<MasterData>>? fetchBloodGroup,
    AsyncValue<List<MasterData>>? fetchRelation,
  
  }) {
    return MasterState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
      fetchGender: fetchGender ?? this.fetchGender,
      fetchBloodGroup: fetchBloodGroup ?? this.fetchBloodGroup,
      fetchRelation: fetchRelation ?? this.fetchRelation,
     
    );
  }
}

class MasterViewModel extends StateNotifier<MasterState> {
  final Ref ref;
  final MasterUsecase usecase;

  MasterViewModel(this.ref, this.usecase) : super(const MasterState());

  Future<void> fetchGenderList() async {
    state = state.copyWith(fetchGender: const AsyncValue.loading());
    try {
      final result = await usecase.fetchGenderList();
      state = state.copyWith(fetchGender: AsyncValue.data(result));
    } catch (e, st) {
      state = state.copyWith(fetchGender: AsyncValue.error(e, st));
    }
  }

  Future<void> fetchBloodGroupList() async {
    state = state.copyWith(fetchBloodGroup: const AsyncValue.loading());
    try {
      final result = await usecase.fetchBloodGroupList();
      state = state.copyWith(fetchBloodGroup: AsyncValue.data(result));
    } catch (e, st) {
      state = state.copyWith(fetchBloodGroup: AsyncValue.error(e, st));
    }
  }

  Future<void> fetchRelationList() async {
    state = state.copyWith(fetchRelation: const AsyncValue.loading());
    try {
      final result = await usecase.fetchRelationList();
      state = state.copyWith(fetchRelation: AsyncValue.data(result));
    } catch (e, st) {
      state = state.copyWith(fetchRelation: AsyncValue.error(e, st));
    }
  }
}