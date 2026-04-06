import 'package:json_annotation/json_annotation.dart';

part 'appointment_request_model.g.dart';

@JsonSerializable(includeIfNull: false)
class AppointmentRequestModel {
  @JsonKey(name: 'appointment_id')
  int? appointmentId;

  @JsonKey(name: 'doctor_id')
  int? doctorId;

  @JsonKey(name: 'patient_id')
  int? patientId;

  @JsonKey(name: 'appointment_date')
  String? appointmentDate;

  @JsonKey(name: 'start_time')
  String? startTime;

  AppointmentRequestModel({
    this.appointmentId,
    this.doctorId,
    this.patientId,
    this.appointmentDate,
    this.startTime,
  });

  factory AppointmentRequestModel.fromJson(Map<String, dynamic> json) =>
      _$AppointmentRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$AppointmentRequestModelToJson(this);
}
