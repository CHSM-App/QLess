import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The connectivity state exposed to the UI.
enum ConnectivityStatus {
  /// App just started — real status not yet determined.
  unknown,
  /// Device has no network connection.
  offline,
  /// Device is back online (shown briefly before transitioning to [online]).
  backOnline,
  /// Device has a working internet connection.
  online,
}

class ConnectivityState {
  final ConnectivityStatus status;
  /// True while the "Back Online" banner should be visible (auto-hides after 2 s).
  final bool showBackOnlineBanner;

  const ConnectivityState({
    this.status = ConnectivityStatus.unknown,
    this.showBackOnlineBanner = false,
  });

  bool get isOffline => status == ConnectivityStatus.offline;
  bool get isOnline  => status == ConnectivityStatus.online ||
                        status == ConnectivityStatus.backOnline;

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    bool? showBackOnlineBanner,
  }) =>
      ConnectivityState(
        status:               status               ?? this.status,
        showBackOnlineBanner: showBackOnlineBanner ?? this.showBackOnlineBanner,
      );
}

/// Riverpod [StateNotifier] that monitors real network reachability.
///
/// * Transitions to [ConnectivityStatus.offline] when connectivity is lost.
/// * Transitions to [ConnectivityStatus.backOnline] for 2 seconds when
///   connectivity is restored, then to [ConnectivityStatus.online].
/// * Uses an actual DNS lookup (like [NetworkService]) to confirm real internet.
class ConnectivityNotifier extends StateNotifier<ConnectivityState>
    with WidgetsBindingObserver {
  ConnectivityNotifier() : super(const ConnectivityState()) {
    _init();
    WidgetsBinding.instance.addObserver(this);
  }

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _bannerTimer;
  Timer? _pollTimer;

  // Background execution limits (Android Doze, backgrounded isolates) can
  // freeze the poll timer or fail the DNS lookup while the app is not in
  // the foreground, leaving state stuck on `offline`. Re-check immediately
  // whenever the app is resumed (e.g. reopened from recents) instead of
  // waiting for the next 10s poll.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckOnResume();
    }
  }

  Future<void> _recheckOnResume() async {
    if (!mounted) return;
    final hasInternet = await _checkInternet();
    if (!mounted) return;
    if (hasInternet && state.isOffline) {
      await _onCameOnline();
    } else if (!hasInternet && state.isOnline) {
      _bannerTimer?.cancel();
      state = state.copyWith(
        status: ConnectivityStatus.offline,
        showBackOnlineBanner: false,
      );
    }
  }

  Future<void> _init() async {
    // Determine initial status immediately
    final hasInternet = await _checkInternet();
    state = state.copyWith(
      status: hasInternet ? ConnectivityStatus.online : ConnectivityStatus.offline,
    );

    // Listen to connectivity changes (adapter on/off)
    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    // Schedule next poll only after the previous one finishes — prevents
    // concurrent DNS lookups when the network is very slow.
    _schedulePoll();
  }

  void _schedulePoll() {
    _pollTimer = Timer(const Duration(seconds: 10), () async {
      if (!mounted) return;
      try {
        final hasInternet = await _checkInternet();
        if (!mounted) return;
        if (!hasInternet && state.isOnline) {
          _bannerTimer?.cancel();
          state = state.copyWith(
            status: ConnectivityStatus.offline,
            showBackOnlineBanner: false,
          );
        } else if (hasInternet && state.isOffline) {
          await _onCameOnline();
        }
      } finally {
        if (mounted) _schedulePoll();
      }
    });
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final hasAdapter = !results.contains(ConnectivityResult.none);

    if (!hasAdapter) {
      _bannerTimer?.cancel();
      state = state.copyWith(
        status:               ConnectivityStatus.offline,
        showBackOnlineBanner: false,
      );
      return;
    }

    // Adapter available — confirm real internet
    final hasInternet = await _checkInternet();
    if (!hasInternet) {
      state = state.copyWith(
        status:               ConnectivityStatus.offline,
        showBackOnlineBanner: false,
      );
      return;
    }

    await _onCameOnline();
  }

  Future<void> _onCameOnline() async {
    final wasOffline = state.isOffline || state.status == ConnectivityStatus.unknown;
    if (wasOffline) {
      state = state.copyWith(
        status:               ConnectivityStatus.backOnline,
        showBackOnlineBanner: true,
      );
      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          state = state.copyWith(
            status:               ConnectivityStatus.online,
            showBackOnlineBanner: false,
          );
        }
      });
    } else {
      state = state.copyWith(status: ConnectivityStatus.online);
    }
  }

  Future<bool> _checkInternet() async {
    if (await _lookupOnce()) return true;
    // Radio can still be waking from doze right after the app resumes from
    // background — retry once before declaring offline to avoid a false
    // offline->online flicker.
    await Future.delayed(const Duration(milliseconds: 800));
    return _lookupOnce();
  }

  Future<bool> _lookupOnce() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _bannerTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}

/// Global provider — watch this anywhere in the app.
final connectivityNotifierProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>(
  (ref) => ConnectivityNotifier(),
);
