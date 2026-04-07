import 'package:json_annotation/json_annotation.dart';

part 'appointment_list.g.dart';

@JsonSerializable()
class AppointmentList {

  @JsonKey(name: 'appointment_id')
  int? appointmentId;

  @JsonKey(name: 'patient_id')
  int? patientId;

  @JsonKey(name: 'doctor_id')
  int? doctorId;

  @JsonKey(name: 'name')
  String? name;

  @JsonKey(name: 'gender')
  String? gender;

  @JsonKey(name: 'appointment_date')
  String? appointmentDate;

  @JsonKey(name: 'DOB')
  String? dob;

  @JsonKey(name: 'queue_number')
  int? queueNumber;

  @JsonKey(name: 'status')
  String? status;
  @JsonKey(name: 'user_type')
  int? userType;


  AppointmentList({
    this.appointmentId,
    this.patientId,
    this.doctorId,
    this.name,
    this.gender,
    this.appointmentDate,
    this.dob,
    this.queueNumber,
    this.status,
    this.userType,
  });

  factory AppointmentList.fromJson(Map<String, dynamic> json) =>
      _$AppointmentListFromJson(json);

  Map<String, dynamic> toJson() => _$AppointmentListToJson(this);

}