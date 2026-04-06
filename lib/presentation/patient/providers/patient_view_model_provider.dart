import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/patient/providers/patient_usecase_provider.dart';
import 'package:qless/presentation/patient/view_models/appointment_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/doctors_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/family_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

final patientLoginViewModelProvider =
    StateNotifierProvider<PatientLoginViewmodel, PatientLoginState>((ref) {
  final usecase = ref.watch(patientLoginUsecaseProvider);
  return PatientLoginViewmodel(usecase);
});



final doctorsViewModelProvider =
    StateNotifierProvider<DoctorsViewmodel, DoctorsState>((ref) {
  final usecase = ref.watch(doctorsUsecaseProvider);
  return DoctorsViewmodel(usecase);
});


final familyViewModelProvider =
    StateNotifierProvider<FamilyViewmodel, FamilyState>((ref) {
  final usecase = ref.watch(familyUsecaseProvider);
  return FamilyViewmodel(usecase);
});

final appointmentViewModelProvider =
    StateNotifierProvider<AppointmentViewmodel, AppointmentState>((ref) {
  final usecase = ref.watch(appointmentUsecaseProvider);
  return AppointmentViewmodel(usecase);
});
