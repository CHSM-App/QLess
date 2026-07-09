import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/view_models/doctor_login_viewmodel.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';

/// Watches [connectivityNotifierProvider] and, whenever the device transitions
/// from offline → online, flushes any pending offline queue operations via
/// [AppointmentListViewmodel.syncPendingOps], plus walk-in patients booked
/// while offline via [ReceptionistLoginViewmodel.syncPendingWalkIns].
///
/// Initialise once at the root (e.g. inside [ProviderScope] via [ref.read] in
/// main.dart, or by watching this provider inside the root widget).
final syncControllerProvider = Provider<void>((ref) {
  ref.listen<ConnectivityState>(connectivityNotifierProvider, (prev, next) async {
    final wasOffline = prev?.isOffline ?? true;
    final isNowOnline = next.isOnline;

    if (wasOffline && isNowOnline) {
      // Determine the current doctor ID from the login ViewModel
      final loginState = ref.read(doctorLoginViewModelProvider);
      final doctorId   = _extractDoctorId(loginState);
      if (doctorId == null) return;

      // Flush prescriptions first so a prescription saved offline lands before
      // the queueNext that closed its consult, then replay the queue ops.
      final prescriptionVm = ref.read(prescriptionViewModelProvider.notifier);
      await prescriptionVm.syncPendingPrescriptions();

      final appointmentVm = ref.read(appointmentViewModelProvider.notifier);
      await appointmentVm.syncPendingOps(doctorId);

      // Walk-in patients booked offline (doctor or receptionist) — queued
      // separately since they don't replay against an existing appointment.
      final receptionistVm = ref.read(receptionistLoginViewModelProvider.notifier);
      await receptionistVm.syncPendingWalkIns();

      // Always refetch on reconnect, even with nothing pending to flush —
      // otherwise a doctor who only viewed (never acted on) the queue while
      // offline stays on stale cached data until they manually pull-to-refresh.
      await appointmentVm.fetchPatientAppointments(doctorId, isOnline: true, silent: true);
    }
  });
});

int? _extractDoctorId(DoctorLoginState state) {
  return state.doctorId;
}
