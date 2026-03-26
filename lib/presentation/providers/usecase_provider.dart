
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/usecase/auth_usecase.dart';
import 'package:qless/domain/usecase/doctor_login_usecase.dart';
import 'package:qless/presentation/providers/repository_provider.dart';


final authUsecaseProvider = Provider<AuthUsecase>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return AuthUsecase(authRepo);
});



final doctorLoginUsecaseProvider = Provider<DoctorLoginUsecase>((ref) {
  final doctorLoginRepo = ref.watch(doctorLoginRepositoryProvider);
  return DoctorLoginUsecase(doctorLoginRepo);
});
