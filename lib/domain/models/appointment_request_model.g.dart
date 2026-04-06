// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppointmentRequestModel _$AppointmentRequestModelFromJson(
<<<<<<< HEAD
  Map<String, dynamic> json,
) => AppointmentRequestModel(
  doctorId: (json['doctor_id'] as num?)?.toInt(),
  patientId: (json['patient_id'] as num?)?.toInt(),
  appointmentId: (json['appointment_id'] as num?)?.toInt(),
  appointmentDate: json['appointment_date'] as String?,
  startTime: json['start_time'] as String?,
  userType: (json['user_type'] as num?)?.toInt(),
);

Map<String, dynamic> _$AppointmentRequestModelToJson(
  AppointmentRequestModel instance,
) => <String, dynamic>{
  'doctor_id': instance.doctorId,
  'patient_id': instance.patientId,
  'appointment_id': instance.appointmentId,
  'appointment_date': instance.appointmentDate,
  'start_time': instance.startTime,
  'user_type': instance.userType,
};
=======
        Map<String, dynamic> json) =>
    AppointmentRequestModel(
      appointmentId: json['appointment_id'] as int?,
      doctorId: json['doctor_id'] as int?,
      patientId: json['patient_id'] as int?,
      appointmentDate: json['appointment_date'] as String?,
      startTime: json['start_time'] as String?,
    );

Map<String, dynamic> _$AppointmentRequestModelToJson(
    AppointmentRequestModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('appointment_id', instance.appointmentId);
  writeNotNull('doctor_id', instance.doctorId);
  writeNotNull('patient_id', instance.patientId);
  writeNotNull('appointment_date', instance.appointmentDate);
  writeNotNull('start_time', instance.startTime);
  return val;
}
>>>>>>> 281541d4bd017b749cc551ec71aecad76c0b047f
