import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/usecase/doctor_login_usecase.dart';
import 'package:qless/presentation/doctor/providers/doctor_repository_provider.dart';

final doctorLoginUsecaseProvider = Provider<DoctorLoginUsecase>((ref) {
  final doctorLoginRepo = ref.watch(doctorLoginRepositoryProvider);
  return DoctorLoginUsecase(doctorLoginRepo);
});
