
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/medicine.dart';

abstract class DoctorLoginRepository {
  Future<dynamic> addDoctorDetails(DoctorDetails doctorLogin);
   Future<List<DoctorDetails>> checkPhoneDoctor(String mobile);

   Future<dynamic> addMedicine(Medicine medicine);

    Future<List<Medicine>> fetchMedicineTypes();

    Future<List<Medicine>> fetchAllMedicines(int doctId);

   

}