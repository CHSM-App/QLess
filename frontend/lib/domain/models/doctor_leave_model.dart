/// A doctor's date-range unavailability (leave / sutti).
/// Plain model — no codegen needed.
class DoctorLeaveModel {
  final int leaveId;
  final String fromDate; // 'yyyy-MM-dd'
  final String toDate; // 'yyyy-MM-dd'
  final String? reason;

  DoctorLeaveModel({
    required this.leaveId,
    required this.fromDate,
    required this.toDate,
    this.reason,
  });

  factory DoctorLeaveModel.fromJson(Map<String, dynamic> json) =>
      DoctorLeaveModel(
        leaveId: (json['leave_id'] as num?)?.toInt() ?? 0,
        fromDate: (json['from_date'] ?? '').toString(),
        toDate: (json['to_date'] ?? '').toString(),
        reason: json['reason'] as String?,
      );
}

/// A single active leave date-range, used by the patient app to grey out
/// unavailable dates in the booking calendar.
class LeaveRange {
  final DateTime from;
  final DateTime to;

  LeaveRange({required this.from, required this.to});

  factory LeaveRange.fromJson(Map<String, dynamic> json) => LeaveRange(
        from: DateTime.parse((json['from_date']).toString()),
        to: DateTime.parse((json['to_date']).toString()),
      );

  /// Inclusive containment check (date-only).
  bool contains(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(DateTime(from.year, from.month, from.day)) &&
        !day.isAfter(DateTime(to.year, to.month, to.day));
  }
}
