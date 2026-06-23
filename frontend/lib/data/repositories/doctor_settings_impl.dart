import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/doctor_leave_model.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/domain/repository/doctor_settings_repo.dart';

class DoctorSettingsImpl implements DoctorSettingsRepo {
  final ApiService apiService;

  DoctorSettingsImpl(this.apiService);

  @override
  Future<dynamic> saveDoctorSchedule(
    DoctorScheduleModel doctorSchedule, {
    bool force = false,
    String action = 'cancel',
    String? clinicId,
  }) {
    final body = <String, dynamic>{
      ...doctorSchedule.toJson(),
      if (clinicId != null) 'clinic_id': clinicId,
      if (force) 'force': true,
      if (force) 'action': action,
    };
    return apiService.saveDoctorSchedule(body);
  }

  @override
  Future<DoctorScheduleModel> getDoctorSchedule(int doctorId, {String? clinicId}) {
    return apiService.getDoctorSchedule(doctorId, clinicId: clinicId);
  }

  @override
  Future<List<DoctorLeaveModel>> getDoctorLeaves(int doctorId) async {
    final res = await apiService.getDoctorLeaves(doctorId);
    final list = (res as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => DoctorLeaveModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<dynamic> addDoctorLeave({
    required int doctorId,
    required String fromDate,
    required String toDate,
    String? reason,
    bool force = false,
  }) {
    final body = <String, dynamic>{
      'doctor_id': doctorId,
      'from_date': fromDate,
      'to_date': toDate,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (force) 'force': true,
    };
    return apiService.addDoctorLeave(body);
  }

  @override
  Future<dynamic> cancelDoctorLeave({
    required int doctorId,
    required int leaveId,
  }) {
    return apiService.cancelDoctorLeave({
      'doctor_id': doctorId,
      'leave_id': leaveId,
    });
  }
}