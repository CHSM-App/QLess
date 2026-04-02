

import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/repository/doctors_repo.dart';

class DoctorsImpl implements DoctorsRepository {
  final ApiService apiService;

  DoctorsImpl(this.apiService);

  @override
  Future<List<DoctorDetails>> fetchDoctors() {
    return apiService.fetchDoctors();
  }

  @override
  Future<List<DoctorAvailabilityModel>> getDoctorAvailability(int doctorId) {
    return apiService.getDoctorAvailability(doctorId);
  }
}