import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/constant.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

class SocketService {
  late final sio.Socket _socket;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _joinedRooms = <int>{};

  SocketService() {
    final serverUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    _socket = sio.io(
      serverUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
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

    // After a reconnect the server has no room state for this socket —
    // re-join every room the client was subscribed to.
    _socket.on('reconnect', (_) {
      for (final id in _joinedRooms) {
        _socket.emit('joinClinic', id);
      }
    });

    _socket.onConnectError((_) {
      // ignore — app works without socket (polling fallback)
    });
  }

  Stream<Map<String, dynamic>> get updates => _controller.stream;

  void joinClinic(int doctorId) {
    _joinedRooms.add(doctorId);
    if (!_socket.connected) _socket.connect();
    _socket.emit('joinClinic', doctorId);
  }

  void leaveClinic(int doctorId) {
    _joinedRooms.remove(doctorId);
    _socket.emit('leaveClinic', doctorId);
    if (_joinedRooms.isEmpty) _socket.disconnect();
  }

  void disconnect() {
    _joinedRooms.clear();
    _socket.disconnect();
  }

  void dispose() {
    _joinedRooms.clear();
    _socket.dispose();
    _controller.close();
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});
