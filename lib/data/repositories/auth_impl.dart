

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
    print("AuthImpl: Attempting to refresh access token with refresh token: ${refreshToken.refreshToken}");
    final result = await apiService.refreshAccessToken(refreshToken);
    print("AuthImpl: Refresh access token result: ${result.accessToken}, ${result.refreshToken}, roleId: ${result.roleId}");
    return result;
  }

  Future<dynamic> saveFcmToken(TokenResponse token) {
      return apiService.saveFcmToken(token);
  }
  
}
