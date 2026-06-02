import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/database/offline_queue_store.dart';
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
  final OfflineQueueStore offlineStore;
  PrescriptionViewmodel(this.usecase, this.offlineStore)
      : super(const PrescriptionState());

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

  /// True when [e] is a loss-of-connectivity failure (no internet, timeout)
  /// rather than a real server rejection — only these trigger offline save.
  bool _isNetworkError(Object e) {
    if (e is SocketException || e is TimeoutException) return true;
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return true;
        case DioExceptionType.unknown:
          return e.error is SocketException;
        default:
          return false;
      }
    }
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network is unreachable') ||
        s.contains('connection refused') ||
        s.contains('connection timed out') ||
        s.contains('connection closed');
  }


//DOCTOR PRESCRIPTION API
  Future<void> insertPrescription(PrescriptionModel prescription) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await usecase.insertPrescription(prescription);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      // Network down — save the prescription offline and let the consult flow
      // continue. It is POSTed automatically once the device reconnects.
      if (_isNetworkError(e)) {
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
  Future<int> syncPendingPrescriptions() async {
    return offlineStore.flushPendingPrescriptions(
      (rx) => usecase.insertPrescription(rx),
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
