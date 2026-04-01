import 'package:qless/domain/models/prescription.dart';

abstract class PrescriptionRepository {
  Future<dynamic> insertPrescription(PrescriptionModel prescription);
   


   

}