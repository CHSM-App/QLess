import 'dart:io';

import 'package:qless/domain/models/receptionist_model.dart';
import 'package:qless/domain/repository/receptionist_repo.dart';

class ReceptionistUsecase {
  final ReceptionistRepository receptionistRepository;

  ReceptionistUsecase(this.receptionistRepository);

  Future<dynamic> addReceptionist(ReceptionistApiModel receptionist, {File? image}) {
    return receptionistRepository.addReceptionist(receptionist, image: image);
  }

  Future<List<ReceptionistApiModel>> fetchReceptionistList(String clinicId) {
    return receptionistRepository.fetchReceptionistList(clinicId);
  }

  Future<List<ReceptionistApiModel>> checkPhoneReceptionist(String mobileNo) {
    return receptionistRepository.checkPhoneReceptionist(mobileNo);
  }

  Future<List<ReceptionistApiModel>> mobileExistReceptionist(String mobileNo) {
    return receptionistRepository.mobileExistReceptionist(mobileNo);
  }

  Future<dynamic> deleteReceptionist(int recepId) {
    return receptionistRepository.deleteReceptionist(recepId);
  }
}
