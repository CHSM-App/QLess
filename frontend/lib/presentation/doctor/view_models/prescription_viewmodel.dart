import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/database/offline_queue_store.dart';
import 'package:qless/core/network/network_errors.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/domain/usecase/prescription_usecase.dart';

/// Sentinel for [PrescriptionState.copyWith] so callers can explicitly clear
/// [error] by passing `error: null`. Without this, `error ?? this.error` makes
/// passing null a no-op and a stale network error can never be cleared — which
/// blocks the Complete/Next flow even after the prescription is saved offline.
const Object _kUnset = Object();

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
    Object? error = _kUnset,
    List<PrescriptionModel>? prescriptionsListPatient,
    List<PrescriptionModel>? prescriptionDetailsPatient,
    List<PrescriptionModel>? appointmentWisePrescriptions,


  }) {
    return PrescriptionState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _kUnset) ? this.error : error as String?,
      prescriptionsListPatient: prescriptionsListPatient ?? this.prescriptionsListPatient,
      prescriptionDetailsPatient: prescriptionDetailsPatient ?? this.prescriptionDetailsPatient,
      appointmentWisePrescriptions: appointmentWisePrescriptions ?? this.appointmentWisePrescriptions,

    );
  }
}

class PrescriptionViewmodel extends StateNotifier<PrescriptionState> {
  final PrescriptionUsecase usecase;
  final OfflineQueueStore offlineStore;
  PrescriptionViewmodel(this.usecase, this.offlineStore)
      : super(const PrescriptionState());

  String _extractError(Object e) => errorMessage(e);


//DOCTOR PRESCRIPTION API
  Future<void> insertPrescription(PrescriptionModel prescription) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await usecase.insertPrescription(prescription);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      // Network down — save the prescription offline and let the consult flow
      // continue. It is POSTed automatically once the device reconnects.
      if (isNetworkError(e)) {
        try {
          await offlineStore.enqueuePrescription(prescription);
          debugPrint('[PrescriptionVM] Saved prescription offline.');
          state = state.copyWith(isLoading: false, error: null);
          return;
        } catch (saveErr) {
          state = state.copyWith(
              isLoading: false, error: 'Could not save offline: $saveErr');
          return;
        }
      }
      state = state.copyWith(isLoading: false, error: _extractError(e));
    }
  }

  /// Flush prescriptions saved offline. Called on reconnect by the sync layer.
  Future<int> syncPendingPrescriptions({int? doctorId}) async {
    return offlineStore.flushPendingPrescriptions(
      (rx) => usecase.insertPrescription(rx),
      doctorId: doctorId,
    );
  }

  Future<void> deleteMedicine(int doctorId, int medicineId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await usecase.deleteMedicine(doctorId, medicineId);
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
