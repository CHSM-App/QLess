import 'package:qless/domain/models/review_model.dart';
import 'package:qless/domain/models/review_request_model.dart';
import 'package:qless/domain/repository/review_repo.dart';

class ReviewUsecase {
  final ReviewRepository reviewRepository;

  ReviewUsecase(this.reviewRepository);

  Future<Map<String, dynamic>> addAppointmentReview(
    ReviewRequestModel reviewRequest,
  ) {
    return reviewRepository.addAppointmentReview(reviewRequest);
  }
  Future<List<ReviewModel>> getAppointmentReviews(int appointmentId) {
    return reviewRepository.getAppointmentReviews(appointmentId);
  }
  Future<List<ReviewModel>> getDoctorReviews(int doctorId) {
    return reviewRepository.getDoctorReviews(doctorId);
  }
}
