// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_preview_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QueuePreviewResponseModel _$QueuePreviewResponseModelFromJson(
  Map<String, dynamic> json,
) => QueuePreviewResponseModel(
  success: _toBool(json['success']),
  predictedQueueNumber: (json['predicted_queue_number'] as num?)?.toInt(),
  patientsAhead: (json['patients_ahead'] as num?)?.toInt(),
  currentQueueSize: (json['current_queue_size'] as num?)?.toInt(),
  avgTime: (json['avg_time'] as num?)?.toDouble(),
  estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
  estimatedArrivalTime: json['estimated_arrival_time'] as String?,
  queueStarted: json['queue_started'] as bool?,
  isMyTurn: json['is_my_turn'] as bool?,
  status: json['status'] as String?,
);

Map<String, dynamic> _$QueuePreviewResponseModelToJson(
  QueuePreviewResponseModel instance,
) => <String, dynamic>{
  'success': instance.success,
  'predicted_queue_number': instance.predictedQueueNumber,
  'patients_ahead': instance.patientsAhead,
  'current_queue_size': instance.currentQueueSize,
  'avg_time': instance.avgTime,
  'estimated_minutes': instance.estimatedMinutes,
  'estimated_arrival_time': instance.estimatedArrivalTime,
  'queue_started': instance.queueStarted,
  'is_my_turn': instance.isMyTurn,
  'status': instance.status,
};
