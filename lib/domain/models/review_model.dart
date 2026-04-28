import 'package:json_annotation/json_annotation.dart';

part 'review_model.g.dart';

num? _numFromJson(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

@JsonSerializable()
class ReviewModel {
  @JsonKey(name: 'review_id')
  int? reviewId;

  @JsonKey(name: 'appointment_id')
  int? appointmentId;

  @JsonKey(name: 'doctor_id')
  int? doctorId;

  @JsonKey(name: 'patient_id')
  int? patientId;

  @JsonKey(name: 'patient_name')
  String? patientName;

  @JsonKey(name: 'name')
  String? name;

  @JsonKey(name: 'rating', fromJson: _numFromJson)
  num? rating;

  @JsonKey(name: 'comment')
  String? comment;

  @JsonKey(name: 'created_at')
  String? createdAt;
    @JsonKey(name: 'reviewed_by_user_id')
  int? reviewedByUserId;


  ReviewModel({
    this.reviewId,
    this.appointmentId,
    this.doctorId,
    this.patientId,
    this.patientName,
    this.name,
    this.rating,
    this.comment,
    this.createdAt,
    this.reviewedByUserId,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) =>
      _$ReviewModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReviewModelToJson(this);
}
