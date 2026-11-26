import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

/// True when [e] is a loss-of-connectivity failure (no internet, timeout,
/// host lookup failed) rather than a real server response. Only these should
/// trigger the offline fallback — a 400/409 from the server is a genuine
/// rejection the user must see.
bool isNetworkError(Object e) {
  // TlsException covers HandshakeException: flaky mobile data or a captive
  // portal breaks the TLS handshake — offline, not a server answer.
  if (e is SocketException || e is TimeoutException || e is TlsException) return true;
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.badCertificate: // captive portal / MITM Wi-Fi
        return true;
      case DioExceptionType.unknown:
        if (e.error is SocketException || e.error is TlsException) return true;
        break; // message-only connectivity failure — sniff below
      default:
        return false; // badResponse / cancel — a real server reply
    }
  }
  // Some layers wrap the cause in a plain Exception(message), and the
  // TokenInterceptor rewrites connection failures to a user-facing string —
  // sniff for both raw socket signatures and those sanitized phrases.
  final s = e.toString().toLowerCase();
  return s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('connection refused') ||
      s.contains('connection timed out') ||
      s.contains('connection closed') ||
      s.contains('handshake') ||
      s.contains('network error') ||
      s.contains('check your connection') ||
      s.contains('request timed out');
}

/// True when the server answered and said no (4xx/5xx with a response).
/// Replaying the same request will not change the answer. 502/503/504 are a
/// proxy or a cold-starting server, not a verdict — those are retried. So is
/// 401: right after reconnecting the token refresh itself can fail on a flaky
/// link; the next sync (or re-login) gets a fresh token.
bool isServerRejection(Object e) {
  if (e is! DioException || e.type != DioExceptionType.badResponse) return false;
  final code = e.response?.statusCode;
  return code != 401 && code != 502 && code != 503 && code != 504;
}

/// Best human-readable message for a failed request.
String errorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is Map && data['msg'] != null) return data['msg'].toString(); // auth/ownership 401/403
    if (data is Map && data['error'] != null) return data['error'].toString(); // 429 rate limit
    return e.message ?? 'Request failed';
  }
  return e.toString().replaceFirst('Exception: ', '');
}
