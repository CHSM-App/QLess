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

  @JsonKey(name: 'family_id')
  int? familyId;

  @JsonKey(name: 'doctor_name')
  String? doctorName;

  @JsonKey(name: 'specialization')
  String? specialization;
  
  @JsonKey(name: 'experience')
  int? experience;

  @JsonKey(name: 'clinic_id')
  String? clinicId;

  @JsonKey(name: 'clinic_name')
  String? clinicName;

  @JsonKey(name: 'clinic_address')
  String? clinicAddress;

  @JsonKey(name: 'clinic_contact')
  String? clinicContact;

  @JsonKey(name: 'latitude')
  double? latitude;

  @JsonKey(name: 'longitude')
  double? longitude;


  @JsonKey(name: 'gender')
  String? gender;

  @JsonKey(name: 'appointment_date')
  String? appointmentDate;

  @JsonKey(name: 'DOB')
  String? dob;


  @JsonKey(name: 'queue_number')
  int? queueNumber;

  @JsonKey(name: 'booking_type')
  int? bookingType;

  @JsonKey(name: 'start_time')
  String? startTime;

  @JsonKey(name: 'end_time')
  String? endTime;

  @JsonKey(name: 'status')
  String? status;


  @JsonKey(name: 'booking_for')
  String? bookingFor;

  @JsonKey(name: 'user_type')
  int? userType;


  @JsonKey(name: 'patient_name')
  String? patientName;


  AppointmentList({
    this.appointmentId,
    this.patientId,
    this.doctorId,
    this.familyId,
    this.doctorName,
    this.specialization,
    this.experience,
    this.clinicId,
    this.gender,
    this.appointmentDate,
    this.dob,
    this.queueNumber,
    this.bookingType,
    this.startTime,
    this.endTime,
    this.status,
    this.userType,
    this.bookingFor,
    this.clinicAddress,
    this.clinicName,
    this.latitude,
    this.longitude,

    this.clinicContact,
  });

  factory AppointmentList.fromJson(Map<String, dynamic> json) =>
      _$AppointmentListFromJson(json);

  Map<String, dynamic> toJson() => _$AppointmentListToJson(this);

}
