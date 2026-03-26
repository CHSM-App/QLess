import '../models/token_response.dart';

abstract class AuthRepository {

  Future<TokenResponse> createLogin(TokenResponse token);
  Future<TokenResponse> refreshAccessToken(TokenResponse refreshToken);
  
}
