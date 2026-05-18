import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';

import 'package:qless/domain/repository/prescription_repo.dart';

class Prescriptionmpl implements PrescriptionRepository {
  final ApiService apiService;

  Prescriptionmpl(this.apiService);


  //DOCTOR PRESCRIPTION API

  @override
  Future<dynamic> insertPrescription(PrescriptionModel prescription) {
    return apiService.insertPrescription(prescription);
  }

  @override
  Future<Medicine> deleteMedicine(int medicineId) {
    return apiService.deleteMedicine(medicineId);
  }



//PATIENT PRESCRIPTION API
@override
  Future<List<PrescriptionModel>> patientPrescriptionDetails(int prescriptionId) {
    return apiService.patientPrescriptionDetails(prescriptionId);
  }


@override
  Future<List<PrescriptionModel>> patientPrescriptionList(int patientId) {
    return apiService.patientPrescriptionList(patientId);
  }

  @override
  Future<List<PrescriptionModel>> appointmentWisePrescription(int appointmentId) {
    return apiService.appointmentWisePrescription(appointmentId);
  }

}
