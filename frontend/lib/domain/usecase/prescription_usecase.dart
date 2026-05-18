
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/domain/repository/prescription_repo.dart';

class PrescriptionUsecase {
  final PrescriptionRepository prescriptionRepository;

  PrescriptionUsecase(this.prescriptionRepository);
//DOCTOR PRESCRIPTION API
  Future<dynamic> insertPrescription(PrescriptionModel prescription) {
    return prescriptionRepository.insertPrescription(prescription);
  }

  Future<Medicine> deleteMedicine(int medicineId) {
    return prescriptionRepository.deleteMedicine(medicineId);
  }

  //PATIENT PRESCRIPTION API
  Future<List<PrescriptionModel>> patientPrescriptionList(int patientId) {
    return prescriptionRepository.patientPrescriptionList(patientId);
  }

  Future<List<PrescriptionModel>> patientPrescriptionDetails(int prescriptionId) {
    return prescriptionRepository.patientPrescriptionDetails(prescriptionId);
  }

  Future<List<PrescriptionModel>> appointmentWisePrescription(int appointmentId) {
    return prescriptionRepository.appointmentWisePrescription(appointmentId);
  }
}
