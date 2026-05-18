

import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/doctor_leave_model.dart';
import 'package:qless/domain/repository/doctors_repo.dart';

class DoctorsImpl implements DoctorsRepository {
  final ApiService apiService;

  DoctorsImpl(this.apiService);

  @override
  Future<List<DoctorDetails>> fetchDoctors(int patientID) {
    return apiService.fetchDoctors(patientID);
  }

  @override
  Future<List<DoctorAvailabilityModel>> getDoctorAvailability(int doctorId) {
    return apiService.getDoctorAvailability(doctorId);
  }

  @override
  Future<List<LeaveRange>> getDoctorLeaveDates(int doctorId) async {
    final res = await apiService.getDoctorLeaveDates(doctorId);
    final list = (res as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => LeaveRange.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}