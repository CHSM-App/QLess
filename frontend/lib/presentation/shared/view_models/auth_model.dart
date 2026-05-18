import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/data/repositories/auth_impl.dart';
import 'package:qless/domain/models/token_response.dart';

class AuthViewModel extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  final AuthImpl authRepository;

  AuthViewModel(this.ref, this.authRepository)
      : super(const AsyncValue.data(null));

  Future<String?> login(TokenResponse token) async {
    state = const AsyncValue.loading();

    try {
      final result = await authRepository.createLogin(token);

      await ref.read(tokenProvider.notifier).saveTokens(
            result.accessToken ?? '',
            result.refreshToken ?? '',
            result.roleId ?? 0,
          );

      state = const AsyncValue.data(null);
      return "success";
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> saveFirebaseToken(TokenResponse token) async {
    try {
    await authRepository.saveFcmToken(token); // POST/PUT to your API
  } catch (e) {
    debugPrint('Failed to save FCM token: $e');
  }
  }
}
