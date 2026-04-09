import 'package:json_annotation/json_annotation.dart';

part 'review_request_model.g.dart';

@JsonSerializable()
class ReviewRequestModel {
  @JsonKey(name: 'appointment_id')
  int appointmentId;

  @JsonKey(name: 'doctor_id')
  int doctorId;

  @JsonKey(name: 'patient_id')
  int patientId;

  @JsonKey(name: 'rating')
  int rating;

  @JsonKey(name: 'comment')
  String? comment;
  
  @JsonKey(name: 'patient_name')
  String? patientName;

  ReviewRequestModel({
    required this.appointmentId,
    required this.doctorId,
    required this.patientId,
    required this.rating,
    this.comment,
    this.patientName,
  });

  factory ReviewRequestModel.fromJson(Map<String, dynamic> json) =>
      _$ReviewRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReviewRequestModelToJson(this);
}
