import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/database/offline_queue_store.dart';
import 'package:qless/core/navigation/navigator_key.dart';
import 'package:qless/presentation/doctor/providers/doctor_repository_provider.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';

/// Replays work saved offline (prescriptions, queue actions, walk-ins).
///
/// Runs when:
///  * the device moves into online from any not-online state — including the
///    first `unknown → online` on a cold start, so work left over from a
///    previous session syncs without waiting for a network toggle;
///  * every 60 s while online with work still pending — covers the backend
///    being down while the internet check (DNS) still passes, where no
///    offline → online transition ever happens.
///
/// Only one sync runs at a time; a trigger during a sync joins it, so the same
/// rows are never sent twice. Initialised once at the root via `ref.read`.
final syncControllerProvider = Provider<void>((ref) {
  Future<void>? inFlight;

  Future<void> sync({required bool refetch}) =>
      inFlight ??= _runSync(ref, refetch: refetch).whenComplete(() => inFlight = null);

  ref.listen<ConnectivityState>(connectivityNotifierProvider, (prev, next) {
    final wasOnline = prev?.isOnline ?? false;
    if (!wasOnline && next.isOnline) sync(refetch: true);
  }, fireImmediately: true);

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
    if (ref.read(connectivityNotifierProvider).isOnline) sync(refetch: false);
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

Future<void> _runSync(Ref ref, {required bool refetch}) async {
  final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
  if (doctorId <= 0) return; // patients have nothing to replay

  final store = ref.read(offlineQueueStoreProvider);
  final appointmentVm = ref.read(appointmentViewModelProvider.notifier);
  int failedBefore = 0;
  int pendingBefore = 0;
  try {
    failedBefore = await store.failedCount();
    pendingBefore = await store.pendingOpsCount();

    // Prescriptions first so one saved offline lands before the queueNext
    // that closed its consult, then the queue ops, then walk-ins (queued
    // separately since they don't replay against an existing appointment).
    await ref.read(prescriptionViewModelProvider.notifier)
        .syncPendingPrescriptions(doctorId: doctorId);
    await appointmentVm.syncPendingOps(doctorId);
    await ref.read(receptionistLoginViewModelProvider.notifier)
        .syncPendingWalkIns(doctorId: doctorId);

    // Always refetch on reconnect, even with nothing pending — otherwise a
    // doctor who only viewed the queue offline stays on stale cached data.
    if (refetch || await store.pendingOpsCount() < pendingBefore) {
      await appointmentVm.fetchPatientAppointments(doctorId, isOnline: true, silent: true);
    }
  } catch (e) {
    debugPrint('[Sync] failed: $e');
  } finally {
    try {
      await appointmentVm.refreshSyncCounts();
      await _reportNewFailures(store, failedBefore);
    } catch (_) {}
  }
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
