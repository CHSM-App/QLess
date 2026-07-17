import 'dart:io';

import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/receptionist_model.dart';

abstract class ReceptionistRepository {
  Future<dynamic> addReceptionist(ReceptionistApiModel receptionist, {File? image});

  Future<List<ReceptionistApiModel>> fetchReceptionistList(int doctorId);

  Future<List<ReceptionistApiModel>> checkPhoneReceptionist(String mobile);

  Future<List<ReceptionistApiModel>> mobileExistReceptionist(String mobileNo);

  Future<dynamic> deleteReceptionist(int recepId);

  Future<AppointmentResponseModel> walkInBook(Map<String, dynamic> body);
}
