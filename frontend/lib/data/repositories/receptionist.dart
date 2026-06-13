import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/data/api/api_service.dart';
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
      int.tryParse(recept.clinicId ?? '') ?? 0,
      multipartImage,
    );
  }

  @override
  Future<List<ReceptionistApiModel>> fetchReceptionistList(String clinicId) {
    final id = int.tryParse(clinicId) ?? 0;
    return apiService.fetchReceptionistList(id);
  }

  @override
  Future<List<ReceptionistApiModel>> checkPhoneReceptionist(String mobileNo) async {
    final response = await apiService.checkPhoneReceptionist(mobileNo);

    if (response.isNotEmpty) {
      await TokenStorage.saveValue('recep_id', response[0].recepId.toString());
      await TokenStorage.saveValue('name', response[0].name.toString());
      await TokenStorage.saveValue('mobile_no', response[0].mobileNo.toString());
      await TokenStorage.saveValue('email', response[0].email.toString());
      await TokenStorage.saveValue('role_id', response[0].roleId.toString());
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
}
