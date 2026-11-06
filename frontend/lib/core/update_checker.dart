import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qless/core/navigation/navigator_key.dart';
import 'package:qless/core/remote_config_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compares the installed version against Remote Config and shows either a
/// blocking (force) or dismissible (soft) update dialog. Android only.
class UpdateChecker {
  UpdateChecker._();

  static bool _shown = false;

  /// Returns <0, 0, >0 like compareTo. Ignores build metadata ("+6").
  static int compareVersions(String a, String b) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final pa = parse(a), pb = parse(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static Future<void> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_shown) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final rc = RemoteConfigService.instance;

      final force = rc.getBool(RemoteConfigService.kForceUpdate) ||
          compareVersions(current,
                  rc.getString(RemoteConfigService.kMinSupportedVersion)) <
              0 ||
          compareVersions(current,
                  rc.getString(RemoteConfigService.kForceUpdateBelowVersion)) <
              0;
      final soft = !force &&
          compareVersions(
                  current, rc.getString(RemoteConfigService.kLatestVersion)) <
              0;
      if (!force && !soft) return;

      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      _shown = true;

      final storeUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=${info.packageName}');

      await showDialog<void>(
        context: ctx,
        barrierDismissible: !force,
        builder: (dCtx) => PopScope(
          canPop: !force,
          child: AlertDialog(
            title: Text(rc.getString(RemoteConfigService.kUpdateTitle)),
            content: Text(rc.getString(RemoteConfigService.kUpdateMessage)),
            actions: [
              if (!force)
                TextButton(
                  onPressed: () => Navigator.of(dCtx).pop(),
                  child: const Text('Later'),
                ),
              TextButton(
                onPressed: () => launchUrl(storeUri,
                    mode: LaunchMode.externalApplication),
                child: const Text('Update Now'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('UpdateChecker failed: $e');
    }
  }
}
