import 'package:json_annotation/json_annotation.dart';

part 'appointment_response_model.g.dart';

// SQL Server has no boolean type — stored procs return success as 1/0 (int),
// so accept int, bool, or string and coerce. Avoids "type 'int' is not a
// subtype of type 'bool'" crashes on cancel/reschedule responses.
bool? _successFromJson(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return null;
}

@JsonSerializable()
class AppointmentResponseModel {
  @JsonKey(name: 'success', fromJson: _successFromJson)
  bool? success;

  @JsonKey(name: 'message')
  String? message;

  @JsonKey(name: 'data')
  List<AppointmentData>? data;

  AppointmentResponseModel({
    this.success,
    this.message,
    this.data,
  });

  factory AppointmentResponseModel.fromJson(Map<String, dynamic> json) =>
      _$AppointmentResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$AppointmentResponseModelToJson(this);
}

@JsonSerializable()
class AppointmentData {
  @JsonKey(name: 'slot_id')
  int? slotId;

  @JsonKey(name: 'start_time')
  String? startTime;

  @JsonKey(name: 'end_time')
  String? endTime;

  @JsonKey(name: 'booking_mode')
  int? bookingMode;

  @JsonKey(name: 'slot_duration')
  int? slotDuration;

  @JsonKey(name: 'max_capacity')
  int? maxCapacity;

  @JsonKey(name: 'max_queue_limit')
  int? maxQueueLimit;

  @JsonKey(name: 'booked_count')
  int? bookedCount;

  @JsonKey(name: 'current_queue')
  int? currentQueue;

  @JsonKey(name: 'next_token')
  int? nextToken;

  AppointmentData({
    this.slotId,
    this.startTime,
    this.endTime,
    this.bookingMode,
    this.slotDuration,
    this.maxCapacity,
    this.maxQueueLimit,
    this.bookedCount,
    this.currentQueue,
    this.nextToken,
  });

  factory AppointmentData.fromJson(Map<String, dynamic> json) =>
      _$AppointmentDataFromJson(json);

  Map<String, dynamic> toJson() => _$AppointmentDataToJson(this);
}