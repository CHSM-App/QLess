import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/domain/usecase/prescription_usecase.dart';

class PrescriptionState {
  final bool isLoading;
  final String? error;
final List<PrescriptionModel>? prescriptionsListPatient;
final List<PrescriptionModel>? prescriptionDetailsPatient;
final List<PrescriptionModel>? appointmentWisePrescriptions;


  const PrescriptionState({
    this.isLoading = false,
    this.error,
    this.prescriptionsListPatient,
    this.prescriptionDetailsPatient,
      this.appointmentWisePrescriptions,


  });

  PrescriptionState copyWith({
    bool? isLoading,
    String? error,
    List<PrescriptionModel>? prescriptionsListPatient,
    List<PrescriptionModel>? prescriptionDetailsPatient,
    List<PrescriptionModel>? appointmentWisePrescriptions,


  }) {
    return PrescriptionState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      prescriptionsListPatient: prescriptionsListPatient ?? this.prescriptionsListPatient,
      prescriptionDetailsPatient: prescriptionDetailsPatient ?? this.prescriptionDetailsPatient,
      appointmentWisePrescriptions: appointmentWisePrescriptions ?? this.appointmentWisePrescriptions,

    );
  }
}

class PrescriptionViewmodel extends StateNotifier<PrescriptionState> {
  final PrescriptionUsecase usecase;
  PrescriptionViewmodel(this.usecase) : super(const PrescriptionState()) ;

  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return e.message ?? 'Request failed';
    }
    return e.toString();
  }


//DOCTOR PRESCRIPTION API
  Future<void> insertPrescription(PrescriptionModel prescription) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await usecase.insertPrescription(prescription);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }

  Future<void> deleteMedicine(int medicineId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await usecase.deleteMedicine(medicineId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }




  ///PATIENT PRESCRIPTION API

  Future<void> patientPrescriptionList(int patientId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final prescriptions = await usecase.patientPrescriptionList(patientId);
      state = state.copyWith(isLoading: false, prescriptionsListPatient: prescriptions);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }

  Future<void> patientPrescriptionDetails(int prescriptionId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final details = await usecase.patientPrescriptionDetails(prescriptionId);
      state = state.copyWith(isLoading: false, prescriptionDetailsPatient: details);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }


  }

  Future<void> appointmentWisePrescription(int appointmentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final prescriptions = await usecase.appointmentWisePrescription(appointmentId);
      state = state.copyWith(isLoading: false, appointmentWisePrescriptions: prescriptions);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }
}
