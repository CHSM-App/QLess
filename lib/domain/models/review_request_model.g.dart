// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReviewRequestModel _$ReviewRequestModelFromJson(Map<String, dynamic> json) =>
    ReviewRequestModel(
      appointmentId: (json['appointment_id'] as num).toInt(),
      doctorId: (json['doctor_id'] as num).toInt(),
      patientId: (json['patient_id'] as num).toInt(),
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      patientName: json['patient_name'] as String?,
      reviewedByUserId: (json['reviewed_by_user_id'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ReviewRequestModelToJson(ReviewRequestModel instance) =>
    <String, dynamic>{
      'appointment_id': instance.appointmentId,
      'doctor_id': instance.doctorId,
      'patient_id': instance.patientId,
      'rating': instance.rating,
      'comment': instance.comment,
      'patient_name': instance.patientName,
      'reviewed_by_user_id': instance.reviewedByUserId,
    };
