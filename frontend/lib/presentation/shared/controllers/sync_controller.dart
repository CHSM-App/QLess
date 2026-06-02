import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/view_models/doctor_login_viewmodel.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';

/// Watches [connectivityNotifierProvider] and, whenever the device transitions
/// from offline → online, flushes any pending offline queue operations via
/// [AppointmentListViewmodel.syncPendingOps].
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
    }
  });
});

int? _extractDoctorId(DoctorLoginState state) {
  return state.doctorId;
}
