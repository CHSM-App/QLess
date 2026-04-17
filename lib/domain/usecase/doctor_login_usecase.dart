import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/repository/doctor_login_repo.dart';

class DoctorLoginUsecase {
  final DoctorLoginRepository doctorLoginRepository;

  DoctorLoginUsecase(this.doctorLoginRepository);

  Future<dynamic> addDoctorDetails(DoctorDetails doctorLogin) {
    return doctorLoginRepository.addDoctorDetails(doctorLogin);
  }

  Future<List<DoctorDetails>> checkPhoneDoctor(String mobile) {
    return doctorLoginRepository.checkPhoneDoctor(mobile);
  }

    Future<dynamic> addMedicine(Medicine medicine) {
    return doctorLoginRepository.addMedicine(medicine);
  }

    Future<List<Medicine>> fetchMedicineTypes() {
    return doctorLoginRepository.fetchMedicineTypes();
  }

     Future<List<Medicine>> fetchAllMedicines(int doctorId) {
    return doctorLoginRepository.fetchAllMedicines(doctorId);
  }

  Future<dynamic> updateLeadTime(DoctorDetails doctor) {
    return doctorLoginRepository.updateLeadTime(doctor);
  }

  Future<List<DoctorDetails>> mobileExistDoctor(String mobile) {
    return doctorLoginRepository.mobileExistDoctor(mobile);
  }

}
