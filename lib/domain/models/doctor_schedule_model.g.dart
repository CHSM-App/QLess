// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doctor_schedule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DoctorScheduleModel _$DoctorScheduleModelFromJson(Map<String, dynamic> json) =>
    DoctorScheduleModel(
      doctorId: (json['doctor_id'] as num?)?.toInt(),
      schedule: (json['schedule'] as List<dynamic>?)
          ?.map((e) => DayScheduleModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DoctorScheduleModelToJson(
  DoctorScheduleModel instance,
) => <String, dynamic>{
  'doctor_id': instance.doctorId,
  'schedule': instance.schedule,
};

DayScheduleModel _$DayScheduleModelFromJson(Map<String, dynamic> json) =>
    DayScheduleModel(
      day: json['day'] as String?,
      isEnabled: (json['is_enabled'] as num?)?.toInt(),
      slots: (json['slots'] as List<dynamic>?)
          ?.map((e) => TimeSlotModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DayScheduleModelToJson(DayScheduleModel instance) =>
    <String, dynamic>{
      'day': instance.day,
      'is_enabled': instance.isEnabled,
      'slots': instance.slots,
    };

TimeSlotModel _$TimeSlotModelFromJson(Map<String, dynamic> json) =>
    TimeSlotModel(
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      bookingMode: (json['booking_mode'] as num?)?.toInt(),
      slotDuration: (json['slot_duration'] as num?)?.toInt(),
      maxQueueLength: (json['max_queue_length'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TimeSlotModelToJson(TimeSlotModel instance) =>
    <String, dynamic>{
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'booking_mode': instance.bookingMode,
      'slot_duration': instance.slotDuration,
      'max_queue_length': instance.maxQueueLength,
    };
