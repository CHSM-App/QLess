import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/patients.dart';

abstract class PatientLoginRepository {
  Future<dynamic> addPatient(Patients patient);

  Future<List<Patients>> checkPhonePatient(String mobile);

  
}
