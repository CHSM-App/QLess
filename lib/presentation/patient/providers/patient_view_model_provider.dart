import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/patient/providers/patient_usecase_provider.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

final patientLoginViewModelProvider =
    StateNotifierProvider<PatientLoginViewmodel, PatientLoginState>((ref) {
  final usecase = ref.watch(patientLoginUsecaseProvider);
  return PatientLoginViewmodel(usecase);
});
