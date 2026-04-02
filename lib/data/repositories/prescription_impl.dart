import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';

import 'package:qless/domain/repository/prescription_repo.dart';

class Prescriptionmpl implements PrescriptionRepository {
  final ApiService apiService;

  Prescriptionmpl(this.apiService);

  @override
  Future<dynamic> insertPrescription(PrescriptionModel prescription) {
    return apiService.insertPrescription(prescription);
  }

  @override
  Future<Medicine> deleteMedicine(int medicineId) {
    return apiService.deleteMedicine(medicineId);
  }


}
