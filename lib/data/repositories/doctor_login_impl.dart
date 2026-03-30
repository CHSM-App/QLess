import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/doctor_login.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/repository/doctor_login_repo.dart';

class DoctorLoginImpl implements DoctorLoginRepository {
  final ApiService apiService;

  DoctorLoginImpl(this.apiService);

  @override
  Future<dynamic> addDoctorDetails(DoctorLogin doctorLogin) {
    return apiService.addDoctorDetails(doctorLogin);
  }

  @override
  Future<List<DoctorLogin>> checkPhoneDoctor(String mobile) async {
    final response = await apiService.checkPhoneDoctor(mobile);

    if (response.isNotEmpty) {
      // Save values in secure storage

      await TokenStorage.saveValue(
        'doctor_id',
        response[0].doctorId.toString(),
      );
      await TokenStorage.saveValue('name', response[0].name.toString());
      await TokenStorage.saveValue('mobile', response[0].mobile.toString());
      await TokenStorage.saveValue('email', response[0].email.toString());
      await TokenStorage.saveValue('role_id', response[0].roleId.toString());
      await TokenStorage.saveValue(
        'clinic_name',
        response[0].clinicName.toString(),
      );
      await TokenStorage.saveValue('token', response[0].Token.toString());

      await TokenStorage.saveValue(
        'clinic_id',
        response[0].clinicId.toString(),
      );
    }
    return response;
  }

    @override
   Future<dynamic> addMedicine(Medicine mediciene) {
    return apiService.addMedicine(mediciene);
  }

      @override
   Future<List<Medicine>> fetchMedicineTypes() {
    return apiService.fetchMedicineTypes();
  }

  @override
   Future<List<Medicine>> fetchAllMedicines(int doctorId) {
    return apiService.fetchAllMedicines(doctorId);
  }

}
