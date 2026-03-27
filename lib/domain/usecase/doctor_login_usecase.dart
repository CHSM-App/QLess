import 'package:qless/domain/models/doctor_login.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/repository/doctor_login_repo.dart';

class DoctorLoginUsecase {
  final DoctorLoginRepository doctorLoginRepository;

  DoctorLoginUsecase(this.doctorLoginRepository);

  Future<dynamic> addDoctorDetails(DoctorLogin doctorLogin) {
    return doctorLoginRepository.addDoctorDetails(doctorLogin);
  }

  Future<List<DoctorLogin>> checkPhoneDoctor(String mobile) {
    return doctorLoginRepository.checkPhoneDoctor(mobile);
  }

    Future<dynamic> addMedicine(Medicine medicine) {
    return doctorLoginRepository.addMedicine(medicine);
  }

    Future<dynamic> fetchMedicineTypes() {
    return doctorLoginRepository.fetchMedicineTypes();
  }
}
