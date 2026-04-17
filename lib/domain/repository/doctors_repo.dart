
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';

abstract class DoctorsRepository {
  Future<List<DoctorDetails>> fetchDoctors(int patientID);
  Future<List<DoctorAvailabilityModel>> getDoctorAvailability(int doctorId);
}