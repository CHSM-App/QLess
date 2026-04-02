// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doctor_availability_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DoctorAvailabilityModel _$DoctorAvailabilityModelFromJson(
  Map<String, dynamic> json,
) => DoctorAvailabilityModel(
  doctorId: (json['doctor_id'] as num?)?.toInt(),
  dayOfWeek: json['day_of_week'] as String?,
  isEnabled: json['is_enabled'] as bool?,
  createdAt: json['created_at'] as String?,
  slotId: (json['slot_id'] as num?)?.toInt(),
  availabilityId: (json['availability_id'] as num?)?.toInt(),
  startTime: json['start_time'] as String?,
  endTime: json['end_time'] as String?,
  bookingMode: (json['booking_mode'] as num?)?.toInt(),
  slotDuration: (json['slot_duration'] as num?)?.toInt(),
);

Map<String, dynamic> _$DoctorAvailabilityModelToJson(
  DoctorAvailabilityModel instance,
) => <String, dynamic>{
  'doctor_id': instance.doctorId,
  'day_of_week': instance.dayOfWeek,
  'is_enabled': instance.isEnabled,
  'created_at': instance.createdAt,
  'slot_id': instance.slotId,
  'availability_id': instance.availabilityId,
  'start_time': instance.startTime,
  'end_time': instance.endTime,
  'booking_mode': instance.bookingMode,
  'slot_duration': instance.slotDuration,
};
