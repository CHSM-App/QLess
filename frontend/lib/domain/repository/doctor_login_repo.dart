
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
   /// [saveIdentity] false when a receptionist is loading their linked
   /// doctor — the doctor's name/mobile/role_id must not overwrite the
   /// logged-in receptionist's own values in storage.
   Future<List<DoctorDetails>> checkPhoneDoctor(
     String mobile, {
     bool saveIdentity = true,
   });

   Future<dynamic> addMedicine(Medicine medicine);

    Future<List<Medicine>> fetchMedicineTypes();

    Future<List<Medicine>> fetchAllMedicines(int doctId);

    Future<List<Medicine>> getMedicineSuggestions(String query);

  Future<dynamic> updateLeadTime(DoctorDetails doctor);

  Future<List<DoctorDetails>> mobileExistDoctor(String mobile);

  Future<List<String>> fetchClinicGallery(String clinicId);
  Future<dynamic> deleteClinicGallery(String clinicId, List<String> imageUrls);
  Future<List<DoctorDetails>> fetchDoctorsByClinic(String clinicId);
  Future<List<DoctorDetails>> getDoctorProfileByClinic({String? clinicId, int? doctorId});

  Future<List<DoctorDetails>> getClinicsForDoctor(int doctorId);
  Future<dynamic> addClinic(DoctorDetails clinic, {List<File>? clinicImages});
  Future<dynamic> updateClinic(DoctorDetails clinic, {List<File>? clinicImages});
  Future<dynamic> deleteClinic(String clinicId, int doctorId);

  //send otp
    Future<OtpResponse> sendOtp(OtpResponse payload);
  Future<OtpResponse> verifyOtp(OtpResponse payload);
}
