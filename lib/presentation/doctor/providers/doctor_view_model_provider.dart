import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/doctor/providers/doctor_usecase_provider.dart';
import 'package:qless/presentation/doctor/view_models/doctor_login_viewmodel.dart';

final doctorLoginViewModelProvider =
    StateNotifierProvider<DoctorLoginViewmodel, DoctorLoginState>((ref) {
  final usecase = ref.watch(doctorLoginUsecaseProvider);
  return DoctorLoginViewmodel(usecase);
});
