// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'available_slots.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MonthSlotData _$MonthSlotDataFromJson(Map<String, dynamic> json) =>
    MonthSlotData(
      bookingDate: json['booking_date'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      isBooked: (json['is_booked'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MonthSlotDataToJson(MonthSlotData instance) =>
    <String, dynamic>{
      'booking_date': instance.bookingDate,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'is_booked': instance.isBooked,
    };
