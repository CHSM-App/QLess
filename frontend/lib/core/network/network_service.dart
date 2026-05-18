// lib/core/network/network_service.dart

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onConnectivityChanged async* {
    // Emit current status immediately so UI can show banner on cold start.
    yield await checkConnection();
    yield await checkRealInternet();

    await for (final result in _connectivity.onConnectivityChanged) {
      yield !result.contains(ConnectivityResult.none);
    }
  }

  Future<bool> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<bool> checkRealInternet() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}
}
