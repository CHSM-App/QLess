import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/database/offline_queue_store.dart';
import 'package:qless/core/navigation/navigator_key.dart';
import 'package:qless/presentation/doctor/providers/doctor_repository_provider.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';

/// Replays work saved offline (medicines, walk-ins, prescriptions, queue
/// actions).
///
/// Runs when:
///  * the device moves into online from any not-online state — including the
///    first `unknown → online` on a cold start, so work left over from a
///    previous session syncs without waiting for a network toggle;
///  * ~1 s after anything is queued while online — an action that timed out
///    online goes to the outbox with no offline → online transition to send it;
///  * every 60 s while online with work still pending — a safety net.
///
/// On reconnect and on login it also downloads what the doctor needs for the
/// rest of the day offline (medicines, medicine types, schedule, leaves).
///
/// Only one sync runs at a time; a trigger during a sync joins it, so the same
/// rows are never sent twice. Initialised once at the root via `ref.read`.
final syncControllerProvider = Provider<void>((ref) {
  Future<void>? inFlight;

  Future<void> sync({required bool refetch, bool prefetch = false}) =>
      inFlight ??= _runSync(ref, refetch: refetch, prefetch: prefetch)
          .whenComplete(() => inFlight = null);

  ref.listen<ConnectivityState>(connectivityNotifierProvider, (prev, next) {
    final wasOnline = prev?.isOnline ?? false;
    if (!wasOnline && next.isOnline) sync(refetch: true, prefetch: true);
  }, fireImmediately: true);

  // Something was just queued: send it now rather than at the next tick.
  final store = ref.read(offlineQueueStoreProvider);
  Timer? debounce;
  void onQueued() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 1), () {
      if (ref.read(connectivityNotifierProvider).isOnline) sync(refetch: false);
    });
  }
  store.changes.addListener(onQueued);
  ref.onDispose(() {
    debounce?.cancel();
    store.changes.removeListener(onQueued);
  });

  // A doctor became known (login, or AuthGate restoring the session on a cold
  // start). Drop unsynced rows another doctor left on this phone (forced
  // logout keeps them) so they are never sent under this account nor kept,
  // then sync — the first online signal can land before the doctor loads.
  ref.listen<int?>(doctorLoginViewModelProvider.select((s) => s.doctorId), (prev, next) async {
    final id = next ?? 0;
    if (id <= 0 || next == prev) return;
    try {
      await ref.read(offlineQueueStoreProvider).deletePendingForOtherDoctors(id);
    } catch (_) {}
    if (ref.read(connectivityNotifierProvider).isOnline) sync(refetch: false, prefetch: true);
  });

  // Whenever the doctor's list loads online, cache today's completed
  // prescriptions so they can be opened offline later in the day.
  ref.listen(appointmentViewModelProvider.select((s) => s.patientAppointmentsList), (_, next) {
    final list = next.valueOrNull;
    if (list == null || !ref.read(connectivityNotifierProvider).isOnline) return;
    if ((ref.read(doctorLoginViewModelProvider).doctorId ?? 0) <= 0) return;
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final ids = list
        .where((a) => (a.status ?? '').toLowerCase() == 'completed' &&
            (a.appointmentDate ?? '').startsWith(today))
        .map((a) => a.appointmentId ?? 0);
    ref.read(prescriptionViewModelProvider.notifier).prefetchTodayPrescriptions(ids);
  });

  final timer = Timer.periodic(const Duration(seconds: 60), (_) async {
    if (!ref.read(connectivityNotifierProvider).isOnline) return;
    try {
      if (await ref.read(offlineQueueStoreProvider).pendingOpsCount() > 0) {
        await sync(refetch: false);
      }
    } catch (_) {}
  });
  ref.onDispose(timer.cancel);
});

Future<void> _runSync(Ref ref, {required bool refetch, required bool prefetch}) async {
  final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
  if (doctorId <= 0) return; // patients have nothing to replay

  final store = ref.read(offlineQueueStoreProvider);
  final appointmentVm = ref.read(appointmentViewModelProvider.notifier);
  int failedBefore = 0;
  int pendingBefore = 0;
  try {
    failedBefore = await store.failedCount();
    pendingBefore = await store.pendingOpsCount();

    // Medicines first, then walk-ins: each swaps its placeholder id for the
    // real one in the rows after it (remapMedicine / remapAppointment), which
    // would otherwise be refused. Then prescriptions, so one saved offline
    // lands before the queueNext that closed its consult, then the queue ops.
    // Repeat while a pass made progress — rows queued during a pass, or held
    // back until their walk-in synced, go out in the same sync.
    var before = pendingBefore;
    for (var pass = 0; pass < 3 && before > 0; pass++) {
      await ref.read(doctorLoginViewModelProvider.notifier)
          .syncPendingMedicines(doctorId: doctorId);
      await ref.read(receptionistLoginViewModelProvider.notifier)
          .syncPendingWalkIns(doctorId: doctorId);
      await ref.read(prescriptionViewModelProvider.notifier)
          .syncPendingPrescriptions(doctorId: doctorId);
      await appointmentVm.syncPendingOps(doctorId);
      final after = await store.pendingOpsCount();
      if (after >= before) break;
      before = after;
    }

    // Always refetch on reconnect, even with nothing pending — otherwise a
    // doctor who only viewed the queue offline stays on stale cached data.
    if (refetch || await store.pendingOpsCount() < pendingBefore) {
      await appointmentVm.fetchPatientAppointments(doctorId, isOnline: true, silent: true);
    }
    if (prefetch) await _downloadTheDay(ref, doctorId);
    // Presence rejoin sent the stored token, which may have expired while
    // offline; the replays above refreshed it — rejoin so patients see the
    // doctor online again.
    appointmentVm.joinClinic(doctorId, clinicId: ref.read(doctorLoginViewModelProvider).clinicId);
  } catch (e) {
    debugPrint('[Sync] failed: $e');
  } finally {
    try {
      await appointmentVm.refreshSyncCounts();
      await _reportNewFailures(store, failedBefore);
    } catch (_) {}
  }
}

/// Everything the doctor's offline day relies on — each call caches what it
/// fetches. Independent: one failing doesn't stop the rest.
Future<void> _downloadTheDay(Ref ref, int doctorId) async {
  final clinicId = ref.read(doctorLoginViewModelProvider).clinicId;
  final doctor = ref.read(doctorLoginViewModelProvider.notifier);
  final settings = ref.read(doctorSettingsViewModelProvider.notifier);
  await Future.wait([
    doctor.fetchAllMedicines(doctorId),
    doctor.fetchMedicineTypes(),
    settings.getDoctorSchedule(doctorId, clinicId: clinicId),
    settings.getDoctorLeaves(doctorId),
  ].map((f) => f.catchError((Object e) => debugPrint('[Sync] download failed: $e'))));
}

/// Tells the doctor when something they did offline was refused by the
/// server (e.g. a walk-in on a leave day) — it would otherwise sit unseen.
Future<void> _reportNewFailures(OfflineQueueStore store, int failedBefore) async {
  final failed = await store.failedCount();
  final newCount = failed - failedBefore;
  if (newCount <= 0) return;
  final items = await store.getFailedItems();
  final reason = newCount == 1 && items.isNotEmpty ? ': ${items.last['last_error']}' : '';
  rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
    content: Text('$newCount offline item${newCount == 1 ? '' : 's'} couldn\'t sync'
        '$reason. See Profile → Sync.'),
    duration: const Duration(seconds: 6),
  ));
}
