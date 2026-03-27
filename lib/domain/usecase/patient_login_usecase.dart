import 'package:qless/domain/models/patients.dart';
import 'package:qless/domain/repository/patient_login_repo.dart';

class PatientLoginUsecase {
  final PatientLoginRepository patientLoginRepository;

  PatientLoginUsecase(this.patientLoginRepository);

  Future<dynamic> addPatient(Patients patient) {
    return patientLoginRepository.addPatient(patient);
  }

  Future<List<Patients>> checkPhonePatient(String mobileNo) {
    return patientLoginRepository.checkPhonePatient(mobileNo);
  }
}
