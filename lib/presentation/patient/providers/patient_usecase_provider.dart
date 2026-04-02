import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/usecase/doctors_usecase.dart';
import 'package:qless/domain/usecase/patient_login_usecase.dart';
import 'package:qless/presentation/patient/providers/patient_repository_provider.dart';

final patientLoginUsecaseProvider = Provider<PatientLoginUsecase>((ref) {
  final patientLoginRepo = ref.watch(patientLoginRepositoryProvider);
  return PatientLoginUsecase(patientLoginRepo);
});

final doctorsUsecaseProvider = Provider<DoctorsUseCase>((ref) {
  final repo = ref.watch(doctorsRepositoryProvider);
  return DoctorsUseCase(repo);
});
