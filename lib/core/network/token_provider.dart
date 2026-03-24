import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/storage/token_storage.dart';

class TokenState {
  final String? accessToken;
  final String? refreshToken;
  final int? roleId;
  final bool isLoading;

  const TokenState({
    this.roleId,
    this.accessToken,
    this.refreshToken,
    this.isLoading = true,
  });

  bool get isLoggedIn =>
      accessToken != null && refreshToken != null && roleId != 0;

  TokenState copyWith({
    String? accessToken,
    String? refreshToken,
    int? roleId,
    bool? isLoading,
  }) {
    return TokenState(
      roleId: roleId ?? this.roleId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TokenNotifier extends StateNotifier<TokenState> {
  TokenNotifier() : super(const TokenState());

  /// Load saved tokens at app start
  Future<void> loadTokens() async {
    final tokens = await TokenStorage.getTokens();
    if (tokens != null) {
      state = state.copyWith(
        accessToken: tokens['accessToken'],
        refreshToken: tokens['refreshToken'],
        roleId: int.parse(tokens['roleId'] ?? '0'),
        isLoading: false,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Save new tokens
  Future<void> saveTokens(
    String accessToken,
    String refreshToken,
    int roleId,
  ) async {
    state = state.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
      roleId: roleId,
    );
    // state = TokenState(accessToken: accessToken, refreshToken: refreshToken, roleId: roleId);
    await TokenStorage.saveTokens(accessToken, refreshToken, roleId);
  }

  /// Clear tokens and trigger logout
  Future<void> clearTokens() async {
    state = const TokenState();
    await TokenStorage.clear();
  }
}

final tokenProvider = StateNotifierProvider<TokenNotifier, TokenState>(
  (ref) => TokenNotifier(),
);
