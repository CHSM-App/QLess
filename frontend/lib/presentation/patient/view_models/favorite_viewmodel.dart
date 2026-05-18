import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/usecase/favorite_usecase.dart';

class FavoriteState {
  final bool isLoading;
  final String? error;
  final Map<int, bool> doctorFavorites;

  const FavoriteState({
    this.isLoading = false,
    this.error,
    this.doctorFavorites = const {},
  });

  FavoriteState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    Map<int, bool>? doctorFavorites,
  }) {
    return FavoriteState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      doctorFavorites: doctorFavorites ?? this.doctorFavorites,
    );
  }
}

class FavoriteViewmodel extends StateNotifier<FavoriteState> {
  final FavoriteUsecase usecase;

  FavoriteViewmodel(this.usecase) : super(const FavoriteState());

  Future<bool> fetchFavoriteStatus(int patientId, int doctorId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await usecase.getFavoriteDoctor(patientId, doctorId);
      final isFav = _asBool(result['is_favorite']);
      final updated = Map<int, bool>.from(state.doctorFavorites);
      updated[doctorId] = isFav;
      state = state.copyWith(isLoading: false, doctorFavorites: updated);
      return isFav;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
      return false;
    }
  }

  Future<bool> addFavoriteDoctor(int patientId, int doctorId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await usecase.addFavoriteDoctor(patientId, doctorId);
      final success = _asBool(result['success'], defaultValue: true);
      final updated = Map<int, bool>.from(state.doctorFavorites);
      updated[doctorId] = true;
      state = state.copyWith(
        isLoading: false,
        doctorFavorites: updated,
      );
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
      return false;
    }
  }

  Future<bool> deleteFavoriteDoctor(int patientId, int doctorId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await usecase.deleteFavoriteDoctor(patientId, doctorId);
      final success = _asBool(result['success'], defaultValue: true);
      final updated = Map<int, bool>.from(state.doctorFavorites);
      updated[doctorId] = false;
      state = state.copyWith(
        isLoading: false,
        doctorFavorites: updated,
      );
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
      return false;
    }
  }

  Future<void> fetchFavoritesForDoctors(
      int patientId, List<int> doctorIds) async {
    if (patientId <= 0 || doctorIds.isEmpty) return;
    final results = await Future.wait(
      doctorIds.map((did) => usecase
          .getFavoriteDoctor(patientId, did)
          .then((r) => MapEntry(did, _asBool(r['is_favorite'])))
          .catchError((_) => MapEntry(did, false))),
    );
    final updated = Map<int, bool>.from(state.doctorFavorites)
      ..addEntries(results);
    state = state.copyWith(doctorFavorites: updated);
  }

  void clearError() => state = state.copyWith(clearError: true);

  bool _asBool(Object? value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().toLowerCase().trim();
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
    return defaultValue;
  }

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
