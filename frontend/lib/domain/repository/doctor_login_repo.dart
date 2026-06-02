
import 'dart:io';

import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/otp_response.dart';

abstract class DoctorLoginRepository {
  Future<dynamic> addDoctorDetails(
    DoctorDetails doctorLogin, {
    File? doctorImage,
    List<File>? clinicImages,
  });
   Future<List<DoctorDetails>> checkPhoneDoctor(String mobile);

   Future<dynamic> addMedicine(Medicine medicine);

    Future<List<Medicine>> fetchMedicineTypes();

    Future<List<Medicine>> fetchAllMedicines(int doctId);

    Future<List<Medicine>> getMedicineSuggestions(String query);

  Future<dynamic> updateLeadTime(DoctorDetails doctor);

  Future<List<DoctorDetails>> mobileExistDoctor(String mobile);

  Future<List<String>> fetchClinicGallery(String clinicId);
  Future<dynamic> deleteClinicGallery(String clinicId, List<String> imageUrls);


  //send otp
    Future<OtpResponse> sendOtp(OtpResponse payload);
  Future<OtpResponse> verifyOtp(OtpResponse payload);
}
