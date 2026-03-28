
import 'package:qless/domain/models/doctor_login.dart';
import 'package:qless/domain/models/medicine.dart';

abstract class DoctorLoginRepository {
  Future<dynamic> addDoctorDetails(DoctorLogin doctorLogin);
   Future<List<DoctorLogin>> checkPhoneDoctor(String mobile);

   Future<dynamic> addMedicine(Medicine medicine);

    Future<List<Medicine>> fetchMedicineTypes();

    Future<List<Medicine>> fetchAllMedicines(int doctId);

}