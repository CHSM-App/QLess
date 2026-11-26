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

  /// WhatsApp the patient ('prescription' | 'followup'). Null when sent,
  /// otherwise the message to show. Online only — never queued.
  Future<String?> sendWhatsApp(int appointmentId, String kind) async {
    try {
      await usecase.sendWhatsApp(appointmentId, kind);
      return null;
    } catch (e) {
      return _extractError(e);
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
    final key = 'rx:patient:$patientId';
    try {
      final prescriptions = await usecase.patientPrescriptionList(patientId);
      state = state.copyWith(isLoading: false, prescriptionsListPatient: prescriptions);
      offlineStore.cacheJson(key, prescriptions.map((p) => p.toJson()).toList())
          .catchError((Object e) => debugPrint('[PrescriptionVM] cache failed: $e'));
    } catch (e) {
      // Offline: show the list from the last time it loaded.
      if (isNetworkError(e)) {
        try {
          final cached = await offlineStore.getCachedJson(key);
          if (cached is List) {
            state = state.copyWith(
              isLoading: false,
              prescriptionsListPatient: cached
                  .map((j) => PrescriptionModel.fromJson(j as Map<String, dynamic>))
                  .toList(),
            );
            return;
          }
        } catch (_) {} // corrupt cache — fall through to the error
      }
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

  /// Loads one appointment's prescription; offline (or for a walk-in that
  /// hasn't synced yet — negative placeholder id) it falls back to the cached
  /// copy, then to the one written offline and still queued.
  Future<void> appointmentWisePrescription(int appointmentId, {int? doctorId}) async {
    // Clear the previous appointment's rows first: copyWith keeps old values
    // on null, so a failed load used to show the last patient's prescription.
    state = state.copyWith(isLoading: true, error: null, appointmentWisePrescriptions: const []);
    if (appointmentId > 0) {
      try {
        final prescriptions = await usecase.appointmentWisePrescription(appointmentId);
        state = state.copyWith(isLoading: false, appointmentWisePrescriptions: prescriptions);
        _cache(appointmentId, prescriptions);
        return;
      } catch (e) {
        if (!isNetworkError(e)) {
          state = state.copyWith(isLoading: false, error: _extractError(e));
          return;
        }
      }
    }
    final offline = await offlineStore.offlineAppointmentPrescription(appointmentId, doctorId: doctorId);
    state = state.copyWith(
      isLoading: false,
      appointmentWisePrescriptions: offline,
      error: offline.isEmpty ? 'Prescription not available offline' : null,
    );
  }

  void _cache(int appointmentId, List<PrescriptionModel> rows) {
    if (rows.isEmpty) return;
    offlineStore.cacheAppointmentPrescription(appointmentId, rows)
        .catchError((Object e) => debugPrint('[PrescriptionVM] cache failed: $e'));
  }

  bool _prefetching = false;

  /// Caches today's completed prescriptions in the background so they open
  /// offline later, not only the ones already viewed. Never touches [state]
  /// (a detail screen may be showing one). Stops at the first network error.
  Future<void> prefetchTodayPrescriptions(Iterable<int> appointmentIds) async {
    if (_prefetching) return;
    _prefetching = true;
    try {
      await offlineStore.pruneCachedPrescriptions();
      for (final id in appointmentIds) {
        if (id <= 0 || await offlineStore.hasCachedAppointmentPrescription(id)) continue;
        try {
          _cache(id, await usecase.appointmentWisePrescription(id));
        } catch (e) {
          if (isNetworkError(e)) break;
        }
      }
    } catch (e) {
      debugPrint('[PrescriptionVM] prefetch failed: $e');
    } finally {
      _prefetching = false;
    }
  }
}
