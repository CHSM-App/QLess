


import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/domain/repository/doctor_settings_repo.dart';

class DoctorSettingsUsecase {
  final DoctorSettingsRepo doctorSettingsRepo;

  DoctorSettingsUsecase(this.doctorSettingsRepo);

  Future<dynamic> saveDoctorSchedule(DoctorScheduleModel doctorSchedule) {
    return doctorSettingsRepo.saveDoctorSchedule(doctorSchedule);
  }

  Future<DoctorScheduleModel> getDoctorSchedule(int doctorId) {
    return doctorSettingsRepo.getDoctorSchedule(doctorId);
  }
}