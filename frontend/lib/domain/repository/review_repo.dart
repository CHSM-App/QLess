import 'package:qless/domain/models/review_model.dart';
import 'package:qless/domain/models/review_request_model.dart';

abstract class ReviewRepository {
  Future<Map<String, dynamic>> addAppointmentReview(
    ReviewRequestModel reviewRequest,
  );

  Future<List<ReviewModel>> getAppointmentReviews(int appointmentId);

  Future<List<ReviewModel>> getDoctorReviews(int doctorId);
}
