// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppointmentRequestModel _$AppointmentRequestModelFromJson(
  Map<String, dynamic> json,
) => AppointmentRequestModel(
  appointmentId: (json['appointment_id'] as num?)?.toInt(),
  doctorId: (json['doctor_id'] as num?)?.toInt(),
  patientId: (json['patient_id'] as num?)?.toInt(),
  appointmentDate: json['appointment_date'] as String?,
  startTime: json['start_time'] as String?,
  userType: (json['user_type'] as num?)?.toInt(),
);

Map<String, dynamic> _$AppointmentRequestModelToJson(
  AppointmentRequestModel instance,
) => <String, dynamic>{
  'appointment_id': ?instance.appointmentId,
  'doctor_id': ?instance.doctorId,
  'patient_id': ?instance.patientId,
  'appointment_date': ?instance.appointmentDate,
  'start_time': ?instance.startTime,
  'user_type': ?instance.userType,
};
