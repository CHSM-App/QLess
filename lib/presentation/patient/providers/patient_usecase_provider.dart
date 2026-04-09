import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/usecase/appointment_usecase.dart';
import 'package:qless/domain/usecase/doctors_usecase.dart';
import 'package:qless/domain/usecase/favorite_usecase.dart';
import 'package:qless/domain/usecase/family_usecase.dart';
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

final familyUsecaseProvider = Provider<FamilyUsecase>((ref) {
  final repo = ref.watch(familyRepositoryProvider);
  return FamilyUsecase(repo);
});

final favoriteUsecaseProvider = Provider<FavoriteUsecase>((ref) {
  final repo = ref.watch(favoriteRepositoryProvider);
  return FavoriteUsecase(repo);
});

final appointmentUsecaseProvider = Provider<AppointmentUsecase>((ref) {
  final repo = ref.watch(appointmentRepositoryProvider);
  return AppointmentUsecase(repo);
});
