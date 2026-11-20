import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

/// True when [e] is a loss-of-connectivity failure (no internet, timeout,
/// host lookup failed) rather than a real server response. Only these should
/// trigger the offline fallback — a 400/409 from the server is a genuine
/// rejection the user must see.
bool isNetworkError(Object e) {
  if (e is SocketException || e is TimeoutException) return true;
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.unknown:
        if (e.error is SocketException) return true;
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
      s.contains('network error') ||
      s.contains('check your connection') ||
      s.contains('request timed out');
}

/// True when the server answered and said no (4xx/5xx with a response).
/// Replaying the same request will not change the answer.
bool isServerRejection(Object e) =>
    e is DioException && e.type == DioExceptionType.badResponse;

/// Best human-readable message for a failed request.
String errorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return e.message ?? 'Request failed';
  }
  return e.toString().replaceFirst('Exception: ', '');
}
