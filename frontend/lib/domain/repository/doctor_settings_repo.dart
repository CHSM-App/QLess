


import 'package:qless/domain/models/doctor_leave_model.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';

abstract class DoctorSettingsRepo {
  Future<dynamic> saveDoctorSchedule(
    DoctorScheduleModel doctorSchedule, {
    bool force,
    String action,
    String? clinicId,
  });

  Future<DoctorScheduleModel> getDoctorSchedule(int doctorId, {String? clinicId});

  Future<List<DoctorLeaveModel>> getDoctorLeaves(int doctorId, {String? clinicId});

  /// Returns the raw response on success. Throws [DioException] with
  /// statusCode 409 when appointments exist and `force` is false.
  Future<dynamic> addDoctorLeave({
    required int doctorId,
    required String fromDate,
    required String toDate,
    String? reason,
    bool force,
    String? clinicId,
  });

  Future<dynamic> cancelDoctorLeave({
    required int doctorId,
    required int leaveId,
    String? clinicId,
  });
}