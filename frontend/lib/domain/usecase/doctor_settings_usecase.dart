


import 'package:qless/domain/models/doctor_leave_model.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/domain/repository/doctor_settings_repo.dart';

class DoctorSettingsUsecase {
  final DoctorSettingsRepo doctorSettingsRepo;

  DoctorSettingsUsecase(this.doctorSettingsRepo);

  Future<dynamic> saveDoctorSchedule(
    DoctorScheduleModel doctorSchedule, {
    bool force = false,
    String action = 'cancel',
    String? clinicId,
  }) {
    return doctorSettingsRepo.saveDoctorSchedule(
      doctorSchedule,
      force: force,
      action: action,
      clinicId: clinicId,
    );
  }

  Future<DoctorScheduleModel> getDoctorSchedule(int doctorId, {String? clinicId}) {
    return doctorSettingsRepo.getDoctorSchedule(doctorId, clinicId: clinicId);
  }

  Future<List<DoctorLeaveModel>> getDoctorLeaves(int doctorId, {String? clinicId}) {
    return doctorSettingsRepo.getDoctorLeaves(doctorId, clinicId: clinicId);
  }

  Future<dynamic> addDoctorLeave({
    required int doctorId,
    required String fromDate,
    required String toDate,
    String? reason,
    bool force = false,
    String? clinicId,
  }) {
    return doctorSettingsRepo.addDoctorLeave(
      doctorId: doctorId,
      fromDate: fromDate,
      toDate: toDate,
      reason: reason,
      force: force,
      clinicId: clinicId,
    );
  }

  Future<dynamic> cancelDoctorLeave({
    required int doctorId,
    required int leaveId,
    String? clinicId,
  }) {
    return doctorSettingsRepo.cancelDoctorLeave(
      doctorId: doctorId,
      leaveId: leaveId,
      clinicId: clinicId,
    );
  }
}