
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/usecase/auth_usecase.dart';
import 'package:qless/domain/usecase/master_usecase.dart';
import 'package:qless/presentation/shared/providers/repository_provider.dart';


final authUsecaseProvider = Provider<AuthUsecase>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return AuthUsecase(authRepo);
});

final masterUsecaseProvider = Provider<MasterUsecase>((ref) {
  final masterRepo = ref.watch(masterRepositoryProvider);
  return MasterUsecase(masterRepo);
});
