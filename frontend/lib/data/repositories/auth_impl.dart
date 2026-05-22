

import 'package:flutter/foundation.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/token_response.dart';
import 'package:qless/domain/repository/auth_repo.dart';

class AuthImpl implements AuthRepository {
  final ApiService apiService;

  AuthImpl(this.apiService);

  @override
  Future<TokenResponse> createLogin(TokenResponse token) {
    return apiService.createLogin(token);
  }

  @override
  Future<TokenResponse>refreshAccessToken(TokenResponse refreshToken) async {
    // Never log token values, even in debug — devs share laptops and
    // screen-share. Existence of refresh attempts + their roleId is enough
    // to correlate; for actual values use the network panel or Dio's
    // LogInterceptor (which is itself debug-only).
    debugPrint('AuthImpl: refresh attempt');
    final result = await apiService.refreshAccessToken(refreshToken);
    debugPrint('AuthImpl: refresh ok, roleId=${result.roleId}');
    return result;
  }

  Future<dynamic> saveFcmToken(TokenResponse token) {
      return apiService.saveFcmToken(token);
  }
  
}
