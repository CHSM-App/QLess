import 'package:json_annotation/json_annotation.dart';

part 'queue_preview_model.g.dart';

@JsonSerializable()
class QueuePreviewResponseModel {

  @JsonKey(name: 'success', fromJson: _toBool)
  bool? success;

  @JsonKey(name: 'predicted_queue_number')
  int? predictedQueueNumber;

  @JsonKey(name: 'patients_ahead')
  int? patientsAhead;

  @JsonKey(name: 'current_queue_size')
  int? currentQueueSize;

  @JsonKey(name: 'avg_time')
  double? avgTime;

  @JsonKey(name: 'estimated_minutes')
  int? estimatedMinutes;

  @JsonKey(name: 'estimated_arrival_time')
  String? estimatedArrivalTime;

  @JsonKey(name: 'queue_started')
  bool? queueStarted;

  @JsonKey(name: 'is_my_turn')
  bool? isMyTurn;

  @JsonKey(name: 'status')
  String? status;

  QueuePreviewResponseModel({
    this.success,
    this.predictedQueueNumber,
    this.patientsAhead,
    this.currentQueueSize,
    this.avgTime,
    this.estimatedMinutes,
    this.estimatedArrivalTime,
    this.queueStarted,
    this.isMyTurn,
    this.status,
  });

  factory QueuePreviewResponseModel.fromJson(Map<String, dynamic> json) =>
      _$QueuePreviewResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$QueuePreviewResponseModelToJson(this);
}

bool? _toBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is int) return v == 1;
  return null;
}