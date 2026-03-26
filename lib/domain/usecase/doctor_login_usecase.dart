

import 'package:qless/domain/models/doctor_login.dart';
import 'package:qless/domain/repository/doctor_login_repo.dart';

class DoctorLoginUsecase {
  final DoctorLoginRepository doctorLoginRepository;

  DoctorLoginUsecase(this.doctorLoginRepository);

  Future<dynamic> addDoctorDetails(DoctorLogin doctorLogin) {
    return doctorLoginRepository.addDoctorDetails(doctorLogin);
  }

}
