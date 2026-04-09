import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/review_model.dart';
import 'package:qless/domain/models/review_request_model.dart';
import 'package:qless/domain/repository/review_repo.dart';

class ReviewImpl implements ReviewRepository {
  final ApiService apiService;

  ReviewImpl(this.apiService);

  @override
  Future<Map<String, dynamic>> addAppointmentReview(
    ReviewRequestModel reviewRequest,
  ) {
    return apiService.addAppointmentReview(reviewRequest).then(_asMap);
  }

  @override
  Future<List<ReviewModel>> getAppointmentReviews(int appointmentId) {
    return apiService.getAppointmentReviews(appointmentId);
  }

  @override
  Future<List<ReviewModel>> getDoctorReviews(int doctorId) {
    return apiService.getDoctorReviews(doctorId);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
