import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/receptionist_model.dart';
import 'package:qless/domain/repository/receptionist_repo.dart';


class ReceptionistImpl implements ReceptionistRepository {
  final ApiService apiService;

  ReceptionistImpl(this.apiService);

  @override
  Future<dynamic> addReceptionist(ReceptionistApiModel recept, {File? image}) async {
    MultipartFile? multipartImage;
    if (image != null) {
      multipartImage = await MultipartFile.fromFile(
        image.path,
        filename: p.basename(image.path),
      );
    }

    return apiService.addReceptionist(
      recept.recepId,
      recept.name ?? "",
      recept.mobileNo ?? "",
      recept.email ?? "",
      recept.address ?? "",
      recept.genderId ?? 0,
      recept.clinicId,
      multipartImage,
      recept.doctorId,
    );
  }

  @override
  Future<List<ReceptionistApiModel>> fetchReceptionistList(int doctorId) {
    return apiService.fetchReceptionistList(doctorId);
  }

  @override
  Future<List<ReceptionistApiModel>> checkPhoneReceptionist(String mobileNo) async {
    final response = await apiService.checkPhoneReceptionist(mobileNo);

    debugPrint('[RecepRepo] checkPhone response count: ${response.length}');

    if (response.isNotEmpty) {
      final r = response[0];
      debugPrint('[RecepRepo] recepId=${r.recepId} name=${r.name} '
          'mobile=${r.mobileNo} email=${r.email} '
          'address=${r.address} genderId=${r.genderId} '
          'clinicId=${r.clinicId} roleId=${r.roleId}');

      if (r.recepId  != null) await TokenStorage.saveValue('recep_id',   r.recepId.toString());
      if (r.name     != null) await TokenStorage.saveValue('name',        r.name!);
      if (r.mobileNo != null) await TokenStorage.saveValue('mobile_no',   r.mobileNo!);
      if (r.email    != null) await TokenStorage.saveValue('recep_email',  r.email!);
      if (r.address  != null) await TokenStorage.saveValue('recep_address', r.address!);
      if (r.genderId != null) await TokenStorage.saveValue('recep_gender_id', r.genderId.toString());
      if (r.roleId   != null) await TokenStorage.saveValue('role_id',     r.roleId.toString());
      if (r.clinicId != null && r.clinicId!.trim().isNotEmpty) {
        await TokenStorage.saveValue('recep_clinic_id', r.clinicId!.trim());
      }
      if (r.doctorId != null) await TokenStorage.saveValue('recep_doctor_id', r.doctorId.toString());
      if (r.doctorMobile != null && r.doctorMobile!.trim().isNotEmpty) {
        await TokenStorage.saveValue('recep_doctor_mobile', r.doctorMobile!.trim());
      }
    }


    return response;
  }

  @override
  Future<List<ReceptionistApiModel>> mobileExistReceptionist(String mobileNo) {
    return apiService.mobileExistReceptionist(mobileNo);
  }

  @override
  Future<dynamic> deleteReceptionist(int recepId) {
    return apiService.deleteReceptionist(recepId);
  }
  
  @override
  Future<dynamic> updateReceptionist(ReceptionistApiModel recept, {File? image}) async {
    MultipartFile? multipartImage;
    if (image != null) {
      multipartImage = await MultipartFile.fromFile(
        image.path,
        filename: p.basename(image.path),
      );
    }
    return apiService.addReceptionist(
      recept.recepId,
      recept.name ?? "",
      recept.mobileNo ?? "",
      recept.email ?? "",
      recept.address ?? "",
      recept.genderId ?? 0,
      recept.clinicId,
      multipartImage,
      recept.doctorId,
    );
  }

  @override
  Future<AppointmentResponseModel> walkInBook(Map<String, dynamic> body) {
    return apiService.walkInBook(body);
  }
}
