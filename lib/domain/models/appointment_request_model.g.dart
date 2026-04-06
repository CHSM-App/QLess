// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppointmentRequestModel _$AppointmentRequestModelFromJson(
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
