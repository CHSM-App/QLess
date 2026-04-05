import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';

abstract class PrescriptionRepository {

  //DOCTOR PRESCRIPTION API
  Future<dynamic> insertPrescription(PrescriptionModel prescription);

  Future<Medicine> deleteMedicine(int medicineId);



  //PATIENT PRESCRIPTION API
  Future<List<PrescriptionModel>> patientPrescriptionList(int patientId);
  Future<List<PrescriptionModel>> patientPrescriptionDetails(int prescriptionId);
}

