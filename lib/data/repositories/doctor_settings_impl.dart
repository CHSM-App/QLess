import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/domain/repository/doctor_settings_repo.dart';

class DoctorSettingsImpl implements DoctorSettingsRepo {
  final ApiService apiService;

  DoctorSettingsImpl(this.apiService);

  @override
  Future<dynamic> saveDoctorSchedule(DoctorScheduleModel doctorSchedule) {
    return apiService.saveDoctorSchedule(doctorSchedule);
  }

  @override
  Future<DoctorScheduleModel> getDoctorSchedule(int doctorId) {
    return apiService.getDoctorSchedule(doctorId);
  }
}