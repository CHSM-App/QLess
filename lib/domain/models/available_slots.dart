import 'package:json_annotation/json_annotation.dart';

part 'available_slots.g.dart';


@JsonSerializable()
class MonthSlotData {
  @JsonKey(name: 'booking_date')
  String? bookingDate;

  @JsonKey(name: 'start_time')
  String? startTime;

  @JsonKey(name: 'end_time')
  String? endTime;

  @JsonKey(name: 'is_booked')
  int? isBooked;

  MonthSlotData({
    this.bookingDate,
    this.startTime,
    this.endTime,
    this.isBooked,
  });

  factory MonthSlotData.fromJson(Map<String, dynamic> json) =>
      _$MonthSlotDataFromJson(json);

  Map<String, dynamic> toJson() => _$MonthSlotDataToJson(this);
}