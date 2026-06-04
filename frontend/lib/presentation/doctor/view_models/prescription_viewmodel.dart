import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/database/offline_queue_store.dart';
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
          if (e.error is SocketException) return true;
          break; // message-only connectivity failure — sniff below
        default:
          return false; // badResponse / cancel — a real server reply
      }
    }
    // Also match the TokenInterceptor's sanitized connectivity messages so a
    // connection failure that reaches us message-only (not a typed
    // DioException) still routes the prescription to offline save instead of
    // surfacing "Network error. Please check your connection." to the doctor.
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network is unreachable') ||
        s.contains('connection refused') ||
        s.contains('connection timed out') ||
        s.contains('connection closed') ||
        s.contains('network error') ||
        s.contains('check your connection') ||
        s.contains('request timed out');
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
