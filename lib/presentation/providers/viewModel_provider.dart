
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/dio_provider.dart';
import 'package:qless/core/network/network_service.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/data/repositories/auth_impl.dart';
import 'package:qless/presentation/viewModels/auth_model.dart';
import 'package:qless/presentation/viewModels/network_model.dart';


final networkServiceProvider = Provider((ref) => NetworkService());

final networkStateProvider =
    StateNotifierProvider<EnhancedNetworkStateNotifier, NetworkState>(
        (ref) => EnhancedNetworkStateNotifier());


final networkStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(networkServiceProvider);
  return service.onConnectivityChanged;
});

final authViewModelProvider =
    StateNotifierProvider<AuthViewModel, AsyncValue<void>>((ref) {
      final dio = ref.watch(dioProvider).value!;
      final authRepo = AuthImpl(ApiService(dio));
      return AuthViewModel(ref, authRepo);
    });
