import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Remote Config.
///
/// Add new keys to [_defaults] AND create them in the Firebase console
/// (Engage > Remote Config) then press "Publish changes".
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  // Keys
  static const kMinAppVersion = 'min_app_version';
  static const kMaintenanceMode = 'maintenance_mode';

  // Force / soft update
  static const kForceUpdate = 'force_update';
  static const kForceUpdateBelowVersion = 'force_update_below_version';
  static const kLatestVersion = 'latest_version';
  static const kMinSupportedVersion = 'minimum_supported_version';
  static const kUpdateTitle = 'update_title';
  static const kUpdateMessage = 'update_message';

  // In-app defaults, used until the first successful fetch (or offline).
  // Empty version strings mean "not configured" -> no update prompt.
  static const Map<String, Object> _defaults = {
    kForceUpdate: false,
    kForceUpdateBelowVersion: '',
    kLatestVersion: '',
    kMinSupportedVersion: '',
    kUpdateTitle: '',
    kUpdateMessage: '',
    kMinAppVersion: '1.0.0',
    kMaintenanceMode: false,
  };

  FirebaseRemoteConfig? _rc;

  Future<void>? _initFuture;

  /// Idempotent and never throws; safe to call without awaiting.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // No throttling in debug so console changes show immediately;
        // Firebase throttles fetches, so keep it at 1 hour in release.
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));
      await rc.setDefaults(_defaults);
      _rc = rc;
    } catch (e) {
      debugPrint('RemoteConfig init failed (using defaults): $e');
    }
    await fetchAndActivate();
  }

  /// Fetches and activates the latest values. Never throws; returns false
  /// when the fetch failed or nothing new was activated.
  Future<bool> fetchAndActivate() async {
    try {
      final rc = _rc ?? FirebaseRemoteConfig.instance;
      final activated = await rc.fetchAndActivate();
      _rc = rc;
      return activated;
    } catch (e) {
      debugPrint('RemoteConfig fetch failed (using cached/defaults): $e');
      return false;
    }
  }

  bool getBool(String key) =>
      _rc?.getBool(key) ?? (_defaults[key] as bool? ?? false);

  String getString(String key) =>
      _rc?.getString(key) ?? (_defaults[key] as String? ?? '');

  int getInt(String key) => _rc?.getInt(key) ?? (_defaults[key] as int? ?? 0);
}
