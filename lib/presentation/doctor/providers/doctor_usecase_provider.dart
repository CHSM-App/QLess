import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/usecase/doctor_login_usecase.dart';
import 'package:qless/domain/usecase/prescription_usecase.dart';
import 'package:qless/presentation/doctor/providers/doctor_repository_provider.dart';

final doctorLoginUsecaseProvider = Provider<DoctorLoginUsecase>((ref) {
  final doctorLoginRepo = ref.watch(doctorLoginRepositoryProvider);
  return DoctorLoginUsecase(doctorLoginRepo);
});

final prescriptionUsecaseProvider = Provider<PrescriptionUsecase>((ref) {
  final prescriptionRepo = ref.watch(prescriptionRepositoryProvider);
  return PrescriptionUsecase(prescriptionRepo);
});
