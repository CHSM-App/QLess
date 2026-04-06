// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppointmentResponseModel _$AppointmentResponseModelFromJson(
  Map<String, dynamic> json,
) => AppointmentResponseModel(
  success: json['success'] as bool?,
  message: json['message'] as String?,
  data: (json['data'] as List<dynamic>?)
      ?.map((e) => AppointmentData.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$AppointmentResponseModelToJson(
  AppointmentResponseModel instance,
) => <String, dynamic>{
  'success': instance.success,
  'message': instance.message,
  'data': instance.data,
};

AppointmentData _$AppointmentDataFromJson(Map<String, dynamic> json) =>
    AppointmentData(
      slotId: (json['slot_id'] as num?)?.toInt(),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      bookingMode: (json['booking_mode'] as num?)?.toInt(),
      slotDuration: (json['slot_duration'] as num?)?.toInt(),
      maxCapacity: (json['max_capacity'] as num?)?.toInt(),
      maxQueueLimit: (json['max_queue_limit'] as num?)?.toInt(),
      bookedCount: (json['booked_count'] as num?)?.toInt(),
      currentQueue: (json['current_queue'] as num?)?.toInt(),
      nextToken: (json['next_token'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AppointmentDataToJson(AppointmentData instance) =>
    <String, dynamic>{
      'slot_id': instance.slotId,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'booking_mode': instance.bookingMode,
      'slot_duration': instance.slotDuration,
      'max_capacity': instance.maxCapacity,
      'max_queue_limit': instance.maxQueueLimit,
      'booked_count': instance.bookedCount,
      'current_queue': instance.currentQueue,
      'next_token': instance.nextToken,
    };
