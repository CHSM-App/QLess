import 'package:json_annotation/json_annotation.dart';

part 'doctor_availability_model.g.dart';

@JsonSerializable()
class DoctorAvailabilityModel {
  @JsonKey(name: 'doctor_id')
  int? doctorId;

  @JsonKey(name: 'day_of_week')
  String? dayOfWeek;

  @JsonKey(name: 'is_enabled')
  bool? isEnabled;

  @JsonKey(name: 'created_at')
  String? createdAt;

  @JsonKey(name: 'slot_id')
  int? slotId;

  @JsonKey(name: 'availability_id')
  int? availabilityId;

  @JsonKey(name: 'start_time')
  String? startTime;

  @JsonKey(name: 'end_time')
  String? endTime;

  @JsonKey(name: 'booking_mode')
  int? bookingMode;

  @JsonKey(name: 'slot_duration')
  int? slotDuration;

  DoctorAvailabilityModel({
    this.doctorId,
    this.dayOfWeek,
    this.isEnabled,
    this.createdAt,
    this.slotId,
    this.availabilityId,
    this.startTime,
    this.endTime,
    this.bookingMode,
    this.slotDuration,
  });

  factory DoctorAvailabilityModel.fromJson(Map<String, dynamic> json) =>
      _$DoctorAvailabilityModelFromJson(json);

  Map<String, dynamic> toJson() => _$DoctorAvailabilityModelToJson(this);
}