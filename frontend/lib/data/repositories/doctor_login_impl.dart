import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/repository/doctor_login_repo.dart';

class DoctorLoginImpl implements DoctorLoginRepository {
  final ApiService apiService;

  DoctorLoginImpl(this.apiService);

  @override
  Future<dynamic> addDoctorDetails(
    DoctorDetails doctorLogin, {
    File? doctorImage,
    List<File>? clinicImages,
  }) async {
    MultipartFile? multipartDoctorImage;
    List<MultipartFile>? multipartClinicImages;

    if (doctorImage != null) {
      multipartDoctorImage = await MultipartFile.fromFile(
        doctorImage.path,
        filename: p.basename(doctorImage.path),
      );
    }

    if (clinicImages != null && clinicImages.isNotEmpty) {
      multipartClinicImages = await Future.wait(
        clinicImages.map((f) => MultipartFile.fromFile(
              f.path,
              filename: p.basename(f.path),
            )),
      );
    }

    return apiService.addDoctorMultipart(
      doctorLogin.doctorId,
      doctorLogin.name ?? "",
      doctorLogin.email ?? "",
      doctorLogin.mobile ?? "",
      doctorLogin.qualification ?? "",
      doctorLogin.licenseNo ?? "",
      doctorLogin.experience?.toString() ?? "0",
      doctorLogin.specialization ?? "",
      doctorLogin.roleId ?? 0,
      doctorLogin.clinicName ?? "",
      doctorLogin.clinicAddress ?? "",
      doctorLogin.latitude?.toString() ?? "0",
      doctorLogin.longitude?.toString() ?? "0",
      doctorLogin.consultationFee != null
          ? doctorLogin.consultationFee.toString()
          : "0",
      doctorLogin.websiteName ?? "",
      doctorLogin.clinicEmail ?? "",
      doctorLogin.clinicContact ?? "",
      doctorLogin.genderId ?? 0,
      multipartDoctorImage,
      multipartClinicImages,
    );
  }

  @override
  Future<List<DoctorDetails>> checkPhoneDoctor(String mobile) async {
    final response = await apiService.checkPhoneDoctor(mobile);

    if (response.isNotEmpty) {
      await TokenStorage.saveValue('doctor_id', response[0].doctorId.toString());
      await TokenStorage.saveValue('name', response[0].name.toString());
      await TokenStorage.saveValue('mobile', response[0].mobile.toString());
      await TokenStorage.saveValue('email', response[0].email.toString());
      await TokenStorage.saveValue('role_id', response[0].roleId.toString());
      await TokenStorage.saveValue('clinic_name', response[0].clinicName.toString());
      await TokenStorage.saveValue('token', response[0].Token.toString());
      await TokenStorage.saveValue('clinic_id', response[0].clinicId.toString());
    }
    return response;
  }

  @override
  Future<dynamic> addMedicine(Medicine mediciene) {
    return apiService.addMedicine(mediciene);
  }

  @override
  Future<List<Medicine>> fetchMedicineTypes() {
    return apiService.fetchMedicineTypes();
  }

  @override
  Future<List<Medicine>> fetchAllMedicines(int doctorId) {
    return apiService.fetchAllMedicines(doctorId);
  }

  @override
  Future<List<Medicine>> getMedicineSuggestions(String query) {
    return apiService.getMedicineSuggestions(query);
  }

   @override
  Future<dynamic> updateLeadTime(DoctorDetails doctor ) {
    return apiService.updateLeadTime(doctor);
  }

  @override
  Future<List<DoctorDetails>> mobileExistDoctor(String mobile) {
    return apiService.mobileExistDoctor(mobile);
  }

  @override
  Future<List<String>> fetchClinicGallery(String clinicId) async {
    final result = await apiService.fetchClinicGallery(clinicId);
    return result.map((e) => e.imageUrl ?? '').where((url) => url.isNotEmpty).toList();
  }

  @override
  Future<dynamic> deleteClinicGallery(String clinicId, List<String> imageUrls) {
    return apiService.deleteClinicGallery({
      "clinic_id": clinicId,
      "image_urls": imageUrls,
    });
  }

}
