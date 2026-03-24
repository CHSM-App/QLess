import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {

  static const _accessTokenKey = 'ACCESS_TOKEN';
  static const _refreshTokenKey = 'REFRESH_TOKEN';
  static const _roleIdKey = 'ROLE_ID';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// SAVE TOKENS
  static Future<void> saveTokens(
      String accessToken,
      String refreshToken,
      int roleId,
      ) async {

    await _storage.write(key: _accessTokenKey, value: accessToken);

    await _storage.write(key: _refreshTokenKey, value: refreshToken);

    await _storage.write(key: _roleIdKey, value: roleId.toString());

  }

  /// GET TOKENS
  static Future<Map<String, String>?> getTokens() async {

    final access = await _storage.read(key: _accessTokenKey);

    final refresh = await _storage.read(key: _refreshTokenKey);

    final roleId = await _storage.read(key: _roleIdKey);

    if (access != null && refresh != null && roleId != null) {

      return {
        "accessToken": access,
        "refreshToken": refresh,
        "roleId": roleId,
      };

    }

    return null;
  }



  /// CLEAR ALL
  static Future<void> clear() async {

    await _storage.deleteAll();

  }


  /// OTHER VALUES
  static Future<void> saveValue(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  static Future<String?> getValue(String key) async {
    return await _storage.read(key: key);
  }

}


