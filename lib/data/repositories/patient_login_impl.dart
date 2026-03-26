import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/domain/repository/patient_login_repo.dart';

class PatientLoginImpl implements PatientLoginRepository {
  final ApiService apiService;

  PatientLoginImpl(this.apiService);

  @override
  Future<dynamic> addPatient(Patients doctorLogin) {
    return apiService.addPatient(doctorLogin);
  }

}
