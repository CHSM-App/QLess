
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/domain/repository/prescription_repo.dart';

class PrescriptionUsecase {
  final PrescriptionRepository prescriptionRepository;

  PrescriptionUsecase(this.prescriptionRepository);

  Future<dynamic> insertPrescription(PrescriptionModel prescription) {
    return prescriptionRepository.insertPrescription(prescription);
  }

  Future<Medicine> deleteMedicine(int medicineId) {
    return prescriptionRepository.deleteMedicine(medicineId);
  }
}
