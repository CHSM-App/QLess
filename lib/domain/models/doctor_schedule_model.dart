import 'package:json_annotation/json_annotation.dart';

part 'doctor_schedule_model.g.dart';

@JsonSerializable()
class DoctorScheduleModel {
  @JsonKey(name: 'doctor_id')
  int? doctorId;

  @JsonKey(name: 'schedule')
  List<DayScheduleModel>? schedule;

  DoctorScheduleModel({
    this.doctorId,
    this.schedule,
  });

  factory DoctorScheduleModel.fromJson(Map<String, dynamic> json) =>
      _$DoctorScheduleModelFromJson(json);

  Map<String, dynamic> toJson() => _$DoctorScheduleModelToJson(this);
}

@JsonSerializable()
class DayScheduleModel {
  @JsonKey(name: 'day')
  String? day;

  @JsonKey(name: 'is_enabled')
  int? isEnabled;

  @JsonKey(name: 'slots')
  List<TimeSlotModel>? slots;

  DayScheduleModel({
    this.day,
    this.isEnabled,
    this.slots,
  });

  factory DayScheduleModel.fromJson(Map<String, dynamic> json) =>
      _$DayScheduleModelFromJson(json);

  Map<String, dynamic> toJson() => _$DayScheduleModelToJson(this);
}

@JsonSerializable()
class TimeSlotModel {
  @JsonKey(name: 'start_time')
  String? startTime;

  @JsonKey(name: 'end_time')
  String? endTime;

  @JsonKey(name: 'booking_mode')
  int? bookingMode;

  @JsonKey(name: 'slot_duration')
  int? slotDuration;

  @JsonKey(name: 'max_queue_length')
  int? maxQueueLength;

  TimeSlotModel({
    this.startTime,
    this.endTime,
    this.bookingMode,
    this.slotDuration,
    this.maxQueueLength,
  });

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) =>
      _$TimeSlotModelFromJson(json);

  Map<String, dynamic> toJson() => _$TimeSlotModelToJson(this);
}