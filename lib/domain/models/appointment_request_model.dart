import 'package:json_annotation/json_annotation.dart';

part 'appointment_request_model.g.dart';

@JsonSerializable()
class AppointmentRequestModel {

  @JsonKey(name: 'operation')
  String? operation;

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

  @JsonKey(name: 'slot_id')
  int? slotId;

  @JsonKey(name: 'queue_id')
  int? queueId;

  @JsonKey(name: 'is_next')
  int? isNext;

  AppointmentRequestModel({
    this.operation,
    this.doctorId,
    this.patientId,
    this.appointmentId,
    this.appointmentDate,
    this.startTime,
    this.userType,
    this.slotId,
    this.queueId,
    this.isNext,
  });

  factory AppointmentRequestModel.fromJson(Map<String, dynamic> json) =>
      _$AppointmentRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$AppointmentRequestModelToJson(this);
}
