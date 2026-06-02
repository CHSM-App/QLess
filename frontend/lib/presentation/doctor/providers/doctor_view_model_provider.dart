import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/doctor/providers/doctor_repository_provider.dart';
import 'package:qless/presentation/doctor/providers/doctor_usecase_provider.dart';
import 'package:qless/presentation/doctor/view_models/appointment_list_viewmodel.dart';
import 'package:qless/presentation/doctor/view_models/doctor_login_viewmodel.dart';
import 'package:qless/presentation/doctor/view_models/doctore_settings_viewmodel.dart';
import 'package:qless/presentation/doctor/view_models/prescription_viewmodel.dart';

final doctorLoginViewModelProvider =
    StateNotifierProvider<DoctorLoginViewmodel, DoctorLoginState>((ref) {
  final usecase      = ref.watch(doctorLoginUsecaseProvider);
  final offlineStore = ref.watch(offlineQueueStoreProvider);
  return DoctorLoginViewmodel(usecase, offlineStore);
});

final prescriptionViewModelProvider =
    StateNotifierProvider<PrescriptionViewmodel, PrescriptionState>((ref) {
  final usecase      = ref.watch(prescriptionUsecaseProvider);
  final offlineStore = ref.watch(offlineQueueStoreProvider);
  return PrescriptionViewmodel(usecase, offlineStore);
});

final doctorSettingsViewModelProvider =
    StateNotifierProvider<DoctorSettingsViewModel, DoctorSettingsState>((ref) {
  final usecase = ref.watch(doctorSettingsUsecaseProvider);
  return DoctorSettingsViewModel(usecase);
});

final appointmentViewModelProvider =
    StateNotifierProvider<AppointmentListViewmodel, AppointmentListState>((ref) {
  final usecase      = ref.watch(appointmentUsecaseProvider);
  final offlineStore = ref.watch(offlineQueueStoreProvider);
  return AppointmentListViewmodel(usecase, offlineStore);
});