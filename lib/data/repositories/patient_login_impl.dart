import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/domain/repository/patient_login_repo.dart';

class PatientLoginImpl implements PatientLoginRepository {
  final ApiService apiService;

  PatientLoginImpl(this.apiService);

  @override
  Future<dynamic> addPatient(Patients doctorLogin) {
    return apiService.addPatient(doctorLogin);
  }

  @override
  Future<List<Patients>> checkPhonePatient(String mobileNo) async {
    final response = await apiService.checkPhonePatient(mobileNo);

    if (response.isNotEmpty) {
      await TokenStorage.saveValue('patient_id', response[0].patientId.toString());
      await TokenStorage.saveValue('name', response[0].name.toString());
      await TokenStorage.saveValue('mobile_no', response[0].mobileNo.toString());
      await TokenStorage.saveValue('email', response[0].email.toString());
      await TokenStorage.saveValue('role_id', response[0].roleId.toString());
    }
    return response;
  }



}
