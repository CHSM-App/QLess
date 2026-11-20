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



  @JsonKey(name: 'symptoms')
  String? symptoms;

  @JsonKey(name: 'clinic_id')
  String? clinicId;

  @JsonKey(name: 'booking_closed')
  bool? bookingClosed;

  /// Set only on actions queued offline (UTC ISO time they were queued) so the
  /// backend can skip stale patient notifications when they are replayed.
  @JsonKey(name: 'offline_queued_at', includeIfNull: false)
  String? offlineQueuedAt;

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
    this.symptoms,
    this.clinicId,
    this.bookingClosed,
    this.offlineQueuedAt,
  });

  factory AppointmentRequestModel.fromJson(Map<String, dynamic> json) =>
      _$AppointmentRequestModelFromJson(json);

  Map<String, dynamic> toJson() => _$AppointmentRequestModelToJson(this);
}
