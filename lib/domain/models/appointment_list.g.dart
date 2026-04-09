// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppointmentList _$AppointmentListFromJson(Map<String, dynamic> json) =>
    AppointmentList(
      appointmentId: (json['appointment_id'] as num?)?.toInt(),
      patientId: (json['patient_id'] as num?)?.toInt(),
      doctorId: (json['doctor_id'] as num?)?.toInt(),
      doctorName: json['doctor_name'] as String?,
      specialization: json['specialization'] as String?,
      experience: (json['experience'] as num?)?.toInt(),
      clinicId: json['clinic_id'] as String?,
      name: json['name'] as String?,
      gender: json['gender'] as String?,
      appointmentDate: json['appointment_date'] as String?,
      dob: json['DOB'] as String?,
      queueNumber: (json['queue_number'] as num?)?.toInt(),
      status: json['status'] as String?,
      userType: (json['user_type'] as num?)?.toInt(),
    )..patientName = json['patient_name'] as String?;

Map<String, dynamic> _$AppointmentListToJson(AppointmentList instance) =>
    <String, dynamic>{
      'appointment_id': instance.appointmentId,
      'patient_id': instance.patientId,
      'doctor_id': instance.doctorId,
      'doctor_name': instance.doctorName,
      'specialization': instance.specialization,
      'experience': instance.experience,
      'clinic_id': instance.clinicId,
      'name': instance.name,
      'gender': instance.gender,
      'appointment_date': instance.appointmentDate,
      'DOB': instance.dob,
      'queue_number': instance.queueNumber,
      'status': instance.status,
      'user_type': instance.userType,
      'patient_name': instance.patientName,
    };
