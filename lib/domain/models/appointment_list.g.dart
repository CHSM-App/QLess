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
      familyId: (json['family_id'] as num?)?.toInt(),
      doctorName: json['doctor_name'] as String?,
      specialization: json['specialization'] as String?,
      experience: (json['experience'] as num?)?.toInt(),
      clinicId: json['clinic_id'] as String?,
      gender: json['gender'] as String?,
      appointmentDate: json['appointment_date'] as String?,
      dob: json['DOB'] as String?,
      queueNumber: (json['queue_number'] as num?)?.toInt(),
      bookingType: (json['booking_type'] as num?)?.toInt(),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      status: json['status'] as String?,
      userType: (json['user_type'] as num?)?.toInt(),
      bookingFor: json['booking_for'] as String?,
      clinicAddress: json['clinic_address'] as String?,
      clinicName: json['clinic_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      clinicContact: json['clinic_contact'] as String?,
      queueStatus: (json['queue_status'] as num?)?.toInt(),
    )..patientName = json['patient_name'] as String?;

Map<String, dynamic> _$AppointmentListToJson(AppointmentList instance) =>
    <String, dynamic>{
      'appointment_id': instance.appointmentId,
      'patient_id': instance.patientId,
      'doctor_id': instance.doctorId,
      'family_id': instance.familyId,
      'doctor_name': instance.doctorName,
      'specialization': instance.specialization,
      'experience': instance.experience,
      'clinic_id': instance.clinicId,
      'clinic_name': instance.clinicName,
      'clinic_address': instance.clinicAddress,
      'clinic_contact': instance.clinicContact,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'gender': instance.gender,
      'appointment_date': instance.appointmentDate,
      'DOB': instance.dob,
      'queue_number': instance.queueNumber,
      'booking_type': instance.bookingType,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'status': instance.status,
      'booking_for': instance.bookingFor,
      'user_type': instance.userType,
      'patient_name': instance.patientName,
      'queue_status': instance.queueStatus,
    };
