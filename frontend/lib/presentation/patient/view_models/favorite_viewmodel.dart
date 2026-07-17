import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/usecase/favorite_usecase.dart';

class FavoriteState {
  final bool isLoading;
  final String? error;
  // key = "${doctorId}_${clinicId}" so same doctor at different clinics tracked separately
  final Map<String, bool> doctorFavorites;

  const FavoriteState({
    this.isLoading = false,
    this.error,
    this.doctorFavorites = const {},
  });

  FavoriteState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    Map<String, bool>? doctorFavorites,
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

  static String _key(int doctorId, String? clinicId) => '${doctorId}_${clinicId ?? ''}';

  Future<bool> fetchFavoriteStatus(int patientId, int doctorId, String clinicId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await usecase.getFavoriteDoctor(patientId, doctorId, clinicId);
      final isFav = _asBool(result['is_favorite']);
      final updated = Map<String, bool>.from(state.doctorFavorites);
      updated[_key(doctorId, clinicId)] = isFav;
      state = state.copyWith(isLoading: false, doctorFavorites: updated);
      return isFav;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
      return false;
    }
  }

  Future<bool> addFavoriteDoctor(int patientId, int doctorId, {String? clinicId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await usecase.addFavoriteDoctor(patientId, doctorId, clinicId: clinicId);
      final success = _asBool(result['success'], defaultValue: true);
      final updated = Map<String, bool>.from(state.doctorFavorites);
      updated[_key(doctorId, clinicId)] = true;
      state = state.copyWith(isLoading: false, doctorFavorites: updated);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
      return false;
    }
  }

  Future<bool> deleteFavoriteDoctor(int patientId, int doctorId, String clinicId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await usecase.deleteFavoriteDoctor(patientId, doctorId, clinicId);
      final success = _asBool(result['success'], defaultValue: true);
      final updated = Map<String, bool>.from(state.doctorFavorites);
      updated[_key(doctorId, clinicId)] = false;
      state = state.copyWith(isLoading: false, doctorFavorites: updated);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
      return false;
    }
  }

  Future<void> fetchFavoritesForDoctors(
      int patientId, List<DoctorDetails> doctors) async {
    if (patientId <= 0) return;
    try {
      final rows = await usecase.getFavoriteDoctors(patientId);
      // SP returns rows with doctor_id + clinic_id — build composite-key set
      final favKeys = <String>{};
      for (final row in rows) {
        if (row is! Map) continue;
        final id  = row['doctor_id'];
        final cid = row['clinic_id']?.toString() ?? '';
        if (id != null) {
          final intId = id is int ? id : int.tryParse('$id') ?? -1;
          if (intId > 0) favKeys.add(_key(intId, cid));
        }
      }
      final updated = Map<String, bool>.from(state.doctorFavorites);
      for (final d in doctors) {
        if (d.doctorId != null) {
          updated[_key(d.doctorId!, d.clinicId)] = favKeys.contains(_key(d.doctorId!, d.clinicId));
        }
      }
      state = state.copyWith(doctorFavorites: updated);
    } catch (_) {}
  }

  /// Wipe all favourite state. Call on logout so the next patient starts clean.
  void reset() => state = const FavoriteState();

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
