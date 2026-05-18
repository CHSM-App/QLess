import 'dart:io';

import 'package:qless/domain/models/patients.dart';

abstract class PatientLoginRepository {
  Future<dynamic> addPatient(Patients patient, {File? image});

  Future<List<Patients>> checkPhonePatient(String mobile);

  Future<List<Patients>> mobileExistPatient(String mobileNo);

}
