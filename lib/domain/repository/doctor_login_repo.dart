
import 'package:qless/domain/models/doctor_login.dart';

abstract class DoctorLoginRepository {
  Future<dynamic> addDoctorDetails(DoctorLogin doctorLogin);


}
