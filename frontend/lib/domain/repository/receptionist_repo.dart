import 'dart:io';

import 'package:qless/domain/models/receptionist_model.dart';

abstract class ReceptionistRepository {
  Future<dynamic> addReceptionist(ReceptionistApiModel receptionist, {File? image});

  Future<List<ReceptionistApiModel>> fetchReceptionistList(String clinicId);

  Future<List<ReceptionistApiModel>> checkPhoneReceptionist(String mobile);

  Future<List<ReceptionistApiModel>> mobileExistReceptionist(String mobileNo);

  Future<dynamic> deleteReceptionist(int recepId);
}
