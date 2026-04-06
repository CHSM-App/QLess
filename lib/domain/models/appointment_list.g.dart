// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppointmentList _$AppointmentListFromJson(Map<String, dynamic> json) =>
    AppointmentList(
      appointmentId: json['appointment_id'] as int?,
      patientId: json['patient_id'] as int?,
      doctorId: json['doctor_id'] as int?,
      name: json['name'] as String?,
      gender: json['gender'] as String?,
      appointmentDate: json['appointment_date'] as String?,
      dob: json['DOB'] as String?,
      queueNumber: json['queue_number'] as int?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$AppointmentListToJson(AppointmentList instance) =>
    <String, dynamic>{
      'appointment_id': instance.appointmentId,
      'patient_id': instance.patientId,
      'doctor_id': instance.doctorId,
      'name': instance.name,
      'gender': instance.gender,
      'appointment_date': instance.appointmentDate,
      'DOB': instance.dob,
      'queue_number': instance.queueNumber,
      'status': instance.status,
    };
