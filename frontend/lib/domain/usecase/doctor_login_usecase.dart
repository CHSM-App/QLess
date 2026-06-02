import 'dart:io';

import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/otp_response.dart';
import 'package:qless/domain/repository/doctor_login_repo.dart';

class DoctorLoginUsecase {
  final DoctorLoginRepository doctorLoginRepository;

  DoctorLoginUsecase(this.doctorLoginRepository);

  Future<dynamic> addDoctorDetails(
    DoctorDetails doctorLogin, {
    File? doctorImage,
    List<File>? clinicImages,
  }) {
    return doctorLoginRepository.addDoctorDetails(
      doctorLogin,
      doctorImage: doctorImage,
      clinicImages: clinicImages,
    );
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

    Future<List<Medicine>> getMedicineSuggestions(String query) {
    return doctorLoginRepository.getMedicineSuggestions(query);
  }

  Future<dynamic> updateLeadTime(DoctorDetails doctor) {
    return doctorLoginRepository.updateLeadTime(doctor);
  }

  Future<List<DoctorDetails>> mobileExistDoctor(String mobile) {
    return doctorLoginRepository.mobileExistDoctor(mobile);
  }

  Future<List<String>> fetchClinicGallery(String clinicId) {
    return doctorLoginRepository.fetchClinicGallery(clinicId);
  }

  Future<dynamic> deleteClinicGallery(String clinicId, List<String> imageUrls) {
    return doctorLoginRepository.deleteClinicGallery(clinicId, imageUrls);
  }
  
  Future<OtpResponse> sendOtp(OtpResponse payload) {
    return doctorLoginRepository.sendOtp(payload);
  }

  Future<OtpResponse> verifyOtp(OtpResponse payload) {
    return doctorLoginRepository.verifyOtp(payload);
  }

}
