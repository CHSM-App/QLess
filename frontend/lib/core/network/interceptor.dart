import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/navigation/navigator_key.dart';
import 'package:qless/domain/models/token_response.dart';

import '../../data/repositories/auth_impl.dart';
import 'token_provider.dart';

class TokenInterceptor extends Interceptor {
  final Dio dio;
  final Ref ref;
  final AuthImpl authRepository;
  bool _isRefreshing = false;
  Future<void>? _refreshFuture;
  bool _isLoggingOut = false;

  TokenInterceptor({
    required this.dio,
    required this.ref,
    required this.authRepository,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ref.read(tokenProvider).accessToken;

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = "Bearer $token";
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final sanitizedErr = _sanitizeError(err);

    final statusCode = err.response?.statusCode;
    final isAuthError = statusCode == 401 || statusCode == 403;
    final isRefreshCall = err.requestOptions.path.contains(
      'login/refreshAccessToken',
    );

    if (!isAuthError) {
      return handler.next(sanitizedErr);
    }

    // If refresh itself fails with auth error, force logout.
    if (isRefreshCall) {
      await _forceLogout();
      return handler.next(sanitizedErr);
    }

    // Prevent infinite loops on a failed retry
    final alreadyRetried = err.requestOptions.extra['__retry'] == true;
    if (alreadyRetried) {
      await _forceLogout();
      return handler.next(sanitizedErr);
    }

    final refreshToken = ref.read(tokenProvider).refreshToken;
    if (refreshToken == null) {
      await _forceLogout();
      return handler.next(sanitizedErr);
    }

    try {
      await _refreshTokens(refreshToken);

      return await _retryRequest(err, handler);
    } catch (e) {
      // Only end the session when the refresh is genuinely REJECTED
      // (401/403 → refresh token dead). A network blip, timeout or cold
      // server on next-day launch must NOT log the user out — keep the
      // tokens and surface the original error so the call can retry.
      if (_isAuthRejection(e)) {
        await _forceLogout();
      }
      return handler.next(sanitizedErr);
    }
  }

  /// True only for a real auth rejection (invalid/expired refresh token),
  /// not for connectivity/timeout/server-down failures.
  bool _isAuthRejection(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      return code == 401 || code == 403;
    }
    return false;
  }

  Future<void> _retryRequest(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final reqOptions = err.requestOptions;
    reqOptions.extra['__retry'] = true;

    // Update header with the new access token
    final newToken = ref.read(tokenProvider).accessToken;
    reqOptions.headers['Authorization'] = "Bearer $newToken";

    try {
      final response = await dio.fetch(reqOptions);
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        handler.next(e);
      } else {
        handler.next(err);
      }
    }
  }

  void _goToLogin() {
    // Microtask defers navigation out of the interceptor callback so we
    // don't push routes mid-error-handling. pushNamedAndRemoveUntil with
    // a false predicate wipes the back stack — the user cannot swipe
    // back into the now-tokenless authenticated screens.
    Future.microtask(() {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/auth',
        (_) => false,
      );
    });
  }

  Future<void> _forceLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    try {
      await ref.read(tokenProvider.notifier).clearTokens();
      _goToLogin();
    } finally {
      // Reset the latch. Without this, a future logout after the user
      // re-logs in within the same TokenInterceptor lifetime is silently
      // skipped — tokens stay populated with bad values and the user
      // gets stuck. clearTokens and pushNamedAndRemoveUntil are both
      // idempotent, so racing 401s in the brief reset window are safe.
      _isLoggingOut = false;
    }
  }

  Future<void> _refreshTokens(String refreshToken) async {
    if (_isRefreshing && _refreshFuture != null) {
      return _refreshFuture!;
    }

    _isRefreshing = true;
    _refreshFuture = () async {
      debugPrint('Refreshing access token...');
      final tokenResponse = await authRepository.refreshAccessToken(
        TokenResponse(refreshToken: refreshToken),
      );

      await ref
          .read(tokenProvider.notifier)
          .saveTokens(
            tokenResponse.accessToken!,
            tokenResponse.refreshToken!,
            tokenResponse.roleId ?? 0,
          );
    }();

    try {
      await _refreshFuture!;
    } finally {
      _isRefreshing = false;
      _refreshFuture = null;
    }
  }

  DioException _sanitizeError(DioException err) {
    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: err.error,
      stackTrace: err.stackTrace,
      message: _buildUserMessage(err),
    );
  }

  String _buildUserMessage(DioException err) {
    final statusCode = err.response?.statusCode;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "Request timed out. Please try again.";
      case DioExceptionType.connectionError:
        return "Network error. Please check your connection.";
      case DioExceptionType.cancel:
        return "Request was cancelled.";
      case DioExceptionType.badResponse:
        if (statusCode == 400) {
          return "Invalid request. Please try again.";
        }
        if (statusCode == 401 || statusCode == 403) {
          return "Session expired. Please sign in again.";
        }
        if (statusCode == 404) {
          return "Requested resource not found.";
        }
        if (statusCode != null && statusCode >= 500) {
          return "Server error. Please try again later.";
        }
        return "Something went wrong. Please try again.";
      case DioExceptionType.unknown:
      default:
        return "Something went wrong. Please try again.";
    }
  }
}
