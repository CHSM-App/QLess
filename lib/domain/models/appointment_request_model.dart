import 'package:json_annotation/json_annotation.dart';

part 'appointment_request_model.g.dart';

@JsonSerializable()
class AppointmentRequestModel {


  @JsonKey(name: 'doctor_id')
  int? doctorId;

  @JsonKey(name: 'patient_id')
  int? patientId;

  @JsonKey(name: 'appointment_id')
  int? appointmentId;

  @JsonKey(name: 'appointment_date')
  String? appointmentDate;

  @JsonKey(name: 'start_time')
  String? startTime;

  @JsonKey(name: 'user_type')
  int? userType;

  AppointmentRequestModel({
    this.doctorId,
    this.patientId,
    this.appointmentId,
    this.appointmentDate,
    this.startTime,
    this.userType,
  });

  factory AppointmentRequestModel.fromJson(Map<String, dynamic> json) =>
      _$AppointmentRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$AppointmentRequestModelToJson(this);
}