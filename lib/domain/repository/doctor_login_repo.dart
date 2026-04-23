
import 'dart:io';

import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/medicine.dart';

abstract class DoctorLoginRepository {
  Future<dynamic> addDoctorDetails(
    DoctorDetails doctorLogin, {
    File? doctorImage,
    File? clinicImage,
  });
   Future<List<DoctorDetails>> checkPhoneDoctor(String mobile);

   Future<dynamic> addMedicine(Medicine medicine);

    Future<List<Medicine>> fetchMedicineTypes();

    Future<List<Medicine>> fetchAllMedicines(int doctId);

  Future<dynamic> updateLeadTime(DoctorDetails doctor);

  Future<List<DoctorDetails>> mobileExistDoctor(String mobile);

}
