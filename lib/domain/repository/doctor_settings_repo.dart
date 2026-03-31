


import 'package:qless/domain/models/doctor_schedule_model.dart';

abstract class DoctorSettingsRepo {
  Future<dynamic> saveDoctorSchedule(DoctorScheduleModel doctorSchedule);

  Future<DoctorScheduleModel> getDoctorSchedule(int doctorId);
}