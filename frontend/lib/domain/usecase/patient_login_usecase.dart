import 'dart:io';

import 'package:qless/domain/models/patients.dart';
import 'package:qless/domain/repository/patient_login_repo.dart';

class PatientLoginUsecase {
  final PatientLoginRepository patientLoginRepository;

  PatientLoginUsecase(this.patientLoginRepository);

  Future<dynamic> addPatient(Patients patient, {File? image, String? loginTicket}) {
    return patientLoginRepository.addPatient(patient, image: image, loginTicket: loginTicket);
  }

  Future<List<Patients>> checkPhonePatient(String mobileNo) {
    return patientLoginRepository.checkPhonePatient(mobileNo);
  }

  Future<List<Patients>> mobileExistPatient(String mobileNo) {
    return patientLoginRepository.mobileExistPatient(mobileNo);
  }

}
