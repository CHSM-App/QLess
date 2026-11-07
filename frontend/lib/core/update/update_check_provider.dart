import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qless/core/services/remote_config_service.dart';
import 'package:qless/core/update/semver.dart';
import 'package:qless/core/update/update_state.dart';

/// Pure decision logic (unit-tested). Any unparsable current/latest version
/// means "up to date" so an unconfigured Remote Config never nags users.
UpdateState evaluateUpdate({
  required String currentVersion,
  required String latestVersion,
  String minimumSupportedVersion = '',
  String forceUpdateBelowVersion = '',
  bool forceUpdateFlag = false,
  String title = '',
  String message = '',
}) {
  final current = SemVer.tryParse(currentVersion);
  final latest = SemVer.tryParse(latestVersion);
  if (current == null || latest == null || latest <= current) {
    return UpdateState.upToDate(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
    );
  }

  final minSupported = SemVer.tryParse(minimumSupportedVersion);
  final forceBelow = SemVer.tryParse(forceUpdateBelowVersion);
  final force = forceUpdateFlag ||
      (minSupported != null && current < minSupported) ||
      (forceBelow != null && current < forceBelow);

  return UpdateState(
    updateAvailable: true,
    forceUpdate: force,
    currentVersion: currentVersion,
    latestVersion: latestVersion,
    dialogTitle: title,
    dialogMessage: message,
  );
}

/// Installed app version (e.g. "1.0.6").
final currentVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// Compares the installed version against Remote Config. Android only; never
/// throws (errors resolve to "up to date"). `ref.invalidate` re-runs it.
final updateCheckProvider = FutureProvider<UpdateState>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const UpdateState.upToDate();
  }
  try {
    final current = await ref.watch(currentVersionProvider.future);
    final rc = RemoteConfigService.instance;
    return evaluateUpdate(
      currentVersion: current,
      latestVersion: rc.getString(RemoteConfigService.kLatestVersion),
      minimumSupportedVersion:
          rc.getString(RemoteConfigService.kMinSupportedVersion),
      forceUpdateBelowVersion:
          rc.getString(RemoteConfigService.kForceUpdateBelowVersion),
      forceUpdateFlag: rc.getBool(RemoteConfigService.kForceUpdate),
      title: rc.getString(RemoteConfigService.kUpdateTitle),
      message: rc.getString(RemoteConfigService.kUpdateMessage),
    );
  } catch (e) {
    debugPrint('Update check failed: $e');
    return const UpdateState.upToDate();
  }
});
