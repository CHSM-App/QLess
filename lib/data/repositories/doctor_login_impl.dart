
import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/doctor_login.dart';
import 'package:qless/domain/repository/doctor_login_repo.dart';

class DoctorLoginImpl implements DoctorLoginRepository {
  final ApiService apiService;

  DoctorLoginImpl(this.apiService);

  @override
  Future<dynamic> addDoctorDetails(DoctorLogin doctorLogin) {
    return apiService.addDoctorDetails(doctorLogin);
  }

}
