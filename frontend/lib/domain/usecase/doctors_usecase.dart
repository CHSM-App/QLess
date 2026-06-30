

import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/doctor_leave_model.dart';
import 'package:qless/domain/repository/doctors_repo.dart';

class DoctorsUseCase {
  final DoctorsRepository doctorsRepository;

  DoctorsUseCase(this.doctorsRepository);

  Future<List<DoctorDetails>> fetchDoctors(int patientID) {
    return doctorsRepository.fetchDoctors(patientID);
  }

  Future<List<DoctorAvailabilityModel>> getDoctorAvailability(int doctorId, String clinicId) {
    return doctorsRepository.getDoctorAvailability(doctorId, clinicId);
  }

  Future<List<LeaveRange>> getDoctorLeaveDates(int doctorId, String clinicId) {
    return doctorsRepository.getDoctorLeaveDates(doctorId, clinicId);
  }
}

