class TodayQueueModel {
  final int? queueId;
  final int? doctorId;
  final String? queueDate;
  final int? slotId;
  final String? startTime;
  final String? endTime;
  final int? queueStatus;
  final int? currentServing;
  final int? currentQueueNo;
  final int? totalQueue;
  final int? completedCount;
  final String? startedAt;
  final String? stoppedAt;

  TodayQueueModel({
    this.queueId,
    this.doctorId,
    this.queueDate,
    this.slotId,
    this.startTime,
    this.endTime,
    this.queueStatus,
    this.currentServing,
    this.currentQueueNo,
    this.totalQueue,
    this.completedCount,
    this.startedAt,
    this.stoppedAt,
  });

  factory TodayQueueModel.fromJson(Map<String, dynamic> json) => TodayQueueModel(
        queueId: json['queue_id'] as int?,
        doctorId: json['doctor_id'] as int?,
        queueDate: json['queue_date'] as String?,
        slotId: json['slot_id'] as int?,
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
        queueStatus: json['queue_status'] as int?,
        currentServing: json['current_serving'] as int?,
        currentQueueNo: json['current_queue_no'] as int?,
        totalQueue: json['total_queue'] as int?,
        completedCount: json['completed_count'] as int?,
        startedAt: json['started_at'] as String?,
        stoppedAt: json['stopped_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'queue_id': queueId,
        'doctor_id': doctorId,
        'queue_date': queueDate,
        'slot_id': slotId,
        'start_time': startTime,
        'end_time': endTime,
        'queue_status': queueStatus,
        'current_serving': currentServing,
        'current_queue_no': currentQueueNo,
        'total_queue': totalQueue,
        'completed_count': completedCount,
        'started_at': startedAt,
        'stopped_at': stoppedAt,
      };
}
