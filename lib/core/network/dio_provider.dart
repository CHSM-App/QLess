

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/interceptor.dart';
import 'package:qless/presentation/viewModels/network_model.dart';

import '../../data/api/api_service.dart';
import '../../data/repositories/auth_impl.dart';
import '../constant.dart';

final authRepoProvider = Provider<AuthImpl>((ref) {
 
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  return AuthImpl(ApiService(dio));
});

final dioProvider = FutureProvider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,          
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

  // Add your token interceptor if needed
  dio.interceptors.add(TokenInterceptor(dio:dio, ref:ref,authRepository: ref.watch(authRepoProvider))); // Create this file if needed

  return dio;
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final dio=ref.watch(dioProvider).value;
  return ApiService(dio!);
});


final apiStateProvider = StateNotifierProvider<ApiStateNotifier, ApiState>((ref) {
  return ApiStateNotifier(ref.watch(apiServiceProvider));
});

