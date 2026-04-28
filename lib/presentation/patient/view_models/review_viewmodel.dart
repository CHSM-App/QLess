import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/review_model.dart';
import 'package:qless/domain/models/review_request_model.dart';
import 'package:qless/domain/usecase/review_usecase.dart';

class ReviewState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final List<ReviewModel>? reviews;


  const ReviewState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.reviews,
  });

  ReviewState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    bool clearError = false,
    List<ReviewModel>? reviews,
  }) {
    return ReviewState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
      reviews: reviews ?? this.reviews,
    );
  }
}

class ReviewViewmodel extends StateNotifier<ReviewState> {
  final ReviewUsecase usecase;

  ReviewViewmodel(this.usecase) : super(const ReviewState());

  Future<void> submitReview(ReviewRequestModel reviewRequest) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await usecase.addAppointmentReview(reviewRequest);
      final ok = _asBool(result['success'], defaultValue: true);
      state = state.copyWith(isLoading: false, isSuccess: ok);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
    }
  }

  Future<bool> addAppointmentReview({
    required int appointmentId,
    required int doctorId,
    required int patientId,
    required int rating,
    required int reviewedByUserId,
    String? comment,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);
    try {
      final request = ReviewRequestModel(
        appointmentId: appointmentId,
        doctorId: doctorId,
        patientId: patientId,
        rating: rating,
        comment: comment,
        reviewedByUserId: reviewedByUserId,
      );
      final result = await usecase.addAppointmentReview(request);
      final ok = _asBool(result['success'], defaultValue: true);
      state = state.copyWith(isLoading: false, isSuccess: ok);
      return ok;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
      return false;
    }
  }

  Future<void> fetchAppointmentReviews(int appointmentId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final reviews = await usecase.getAppointmentReviews(appointmentId);
      state = state.copyWith(isLoading: false, reviews: reviews);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
    }
  }

  Future<void> fetchDoctorReviews(int doctorId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final reviews = await usecase.getDoctorReviews(doctorId);
      state = state.copyWith(isLoading: false, reviews: reviews);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractMessage(e));
    }
  }

  bool _asBool(Object? value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().toLowerCase().trim();
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
    return defaultValue;
  }

  String _extractMessage(Object error) {
    if (error is DioError) {
      if (error.response != null && error.response?.data != null) {
        final data = error.response!.data;
        if (data is Map<String, dynamic> && data['message'] != null) {
          return data['message'];
        }
      }
      return 'Network error: ${error.message}';
    }
    return 'An unexpected error occurred';
  }
}
