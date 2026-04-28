// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReviewModel _$ReviewModelFromJson(Map<String, dynamic> json) => ReviewModel(
  reviewId: (json['review_id'] as num?)?.toInt(),
  appointmentId: (json['appointment_id'] as num?)?.toInt(),
  doctorId: (json['doctor_id'] as num?)?.toInt(),
  patientId: (json['patient_id'] as num?)?.toInt(),
  patientName: json['patient_name'] as String?,
  name: json['name'] as String?,
  rating: json['rating'] as num?,
  comment: json['comment'] as String?,
  createdAt: json['created_at'] as String?,
  reviewedByUserId: (json['reviewed_by_user_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$ReviewModelToJson(ReviewModel instance) =>
    <String, dynamic>{
      'review_id': instance.reviewId,
      'appointment_id': instance.appointmentId,
      'doctor_id': instance.doctorId,
      'patient_id': instance.patientId,
      'patient_name': instance.patientName,
      'name': instance.name,
      'rating': instance.rating,
      'comment': instance.comment,
      'created_at': instance.createdAt,
      'reviewed_by_user_id': instance.reviewedByUserId,
    };
