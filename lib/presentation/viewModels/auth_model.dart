import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/data/repositories/auth_impl.dart';



/// Provider for AuthViewModel


class AuthViewModel extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  final AuthImpl authRepository;

  AuthViewModel(this.ref, this.authRepository)
    : super(const AsyncValue.data(null));

  // /// Login function
  // Future<String?> login(TokenResponse token) async {
  //   state = const AsyncValue.loading();

  //   try {
  //     // 🔹 Call API
  //     final result = await authRepository.createLogin(token);
  //     // result should be TokenResponse

  //     // ✅ Save tokens to Riverpod + SecureStorage
  //     await ref
  //         .read(tokenProvider.notifier)
  //         .saveTokens(
  //           result.accessToken?? '',
  //           result.refreshToken ?? "",
  //           result.roleId ?? 0,
  //         );

  //     // await ref.read(tokenProvider.notifier).loadTokens();

  //     state = const AsyncValue.data(null);
  //     return "sucesss"; // Return TokenResponse for UI navigation
  //   } catch (e, st) {
  //     state = AsyncValue.error(e, st);
  //     return null;
  //   }
  // }
}
