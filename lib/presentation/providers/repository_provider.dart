
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/dio_provider.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/data/repositories/auth_impl.dart';
import 'package:qless/domain/repository/auth_repo.dart';




//Auth Repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider).value!;
  final api = ApiService(dio);
  return AuthImpl(api);
});
