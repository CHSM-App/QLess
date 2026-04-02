import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';

abstract class PrescriptionRepository {
  Future<dynamic> insertPrescription(PrescriptionModel prescription);
   

Future<Medicine> deleteMedicine(int medicineId);
   

}