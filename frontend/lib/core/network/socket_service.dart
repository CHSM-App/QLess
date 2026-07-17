import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/constant.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

class SocketService {
  late final sio.Socket _socket;
  final _controller       = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _joinedRooms      = <int>{};
  final _doctorRooms      = <int>{}; // rooms joined as doctor (for reconnect)

  SocketService() {
    final serverUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    _socket = sio.io(
      serverUrl,
      sio.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(double.infinity)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .build(),
    );

    _socket.on('queue_update', (data) {
      if (data is Map) {
        _controller.add(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('doctor_status', (data) {
      if (data is Map) {
        _statusController.add(Map<String, dynamic>.from(data));
      }
    });

    // After a reconnect re-join all rooms (patient + doctor).
    _socket.on('reconnect', (_) {
      for (final id in _joinedRooms) {
        _socket.emit('joinClinic', id);
      }
      for (final id in _doctorRooms) {
        _socket.emit('doctorJoinClinic', id);
      }
    });

    _socket.onConnectError((_) {
      // ignore — app works without socket (polling fallback)
    });
  }

  Stream<Map<String, dynamic>> get updates       => _controller.stream;
  Stream<Map<String, dynamic>> get doctorStatusUpdates => _statusController.stream;

  // Patient-side join (no presence tracking on server)
  void joinClinic(int doctorId) {
    _joinedRooms.add(doctorId);
    if (!_socket.connected) _socket.connect();
    _socket.emit('joinClinic', doctorId);
  }

  // Doctor-side join — server tracks socket for offline detection
  void doctorJoinClinic(int doctorId) {
    _doctorRooms.add(doctorId);
    if (!_socket.connected) _socket.connect();
    _socket.emit('doctorJoinClinic', doctorId);
  }

  void leaveClinic(int doctorId) {
    _joinedRooms.remove(doctorId);
    _doctorRooms.remove(doctorId);
    _socket.emit('leaveClinic', doctorId);
    if (_joinedRooms.isEmpty && _doctorRooms.isEmpty) _socket.disconnect();
  }

  // Explicit doctor logout — tells the server to mark this doctor offline
  // immediately, skipping the reconnect grace period used for network blips.
  // Callers that follow this with disconnect() must await it first: emit()
  // only queues the message, so disconnecting right away can close the
  // transport before the event reaches the server, leaving the server to
  // see a bare disconnect and (wrongly) report a network problem instead.
  //
  // If the doctor's net dropped earlier and the socket is still mid-reconnect
  // at logout time, `_socket.connected` is false — force a (re)connect and
  // wait briefly for it, otherwise the logout signal never reaches the
  // server and the patient stays stuck seeing a stale "network problem"
  // banner even though the doctor explicitly logged out.
  Future<void> doctorLogout(int doctorId) async {
    if (!_socket.connected) {
      _socket.connect();
      final completer = Completer<void>();
      void onConnect(_) {
        if (!completer.isCompleted) completer.complete();
      }
      _socket.on('connect', onConnect);
      await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
      _socket.off('connect', onConnect);
    }
    if (_socket.connected) {
      _socket.emit('doctorLogout', doctorId);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _doctorRooms.remove(doctorId);
  }

  void disconnect() {
    _joinedRooms.clear();
    _doctorRooms.clear();
    _socket.disconnect();
  }

  void dispose() {
    _joinedRooms.clear();
    _doctorRooms.clear();
    _socket.dispose();
    _controller.close();
    _statusController.close();
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});


