import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qless/core/network/socket_service.dart';
import 'package:qless/presentation/doctor/providers/doctor_repository_provider.dart';
import 'package:qless/presentation/patient/providers/patient_usecase_provider.dart';
import 'package:qless/presentation/patient/view_models/appointment_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/doctors_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/favorite_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/family_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/review_viewmodel.dart';

/// Shared position used for nearby-doctor filtering across screens.
/// Updated by HomeScreen whenever the user changes their location.
final selectedPositionProvider = StateProvider<Position?>((ref) => null);

final patientLoginViewModelProvider =
    StateNotifierProvider<PatientLoginViewmodel, PatientLoginState>((ref) {
  final usecase = ref.watch(patientLoginUsecaseProvider);
  final offlineStore = ref.watch(offlineQueueStoreProvider);
  return PatientLoginViewmodel(usecase, offlineStore);
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

final favoriteViewModelProvider =
    StateNotifierProvider<FavoriteViewmodel, FavoriteState>((ref) {
  final usecase = ref.watch(favoriteUsecaseProvider);
  return FavoriteViewmodel(usecase);
});

final appointmentViewModelProvider =
    StateNotifierProvider<AppointmentViewmodel, AppointmentState>((ref) {
  final usecase      = ref.watch(appointmentUsecaseProvider);
  final offlineStore = ref.watch(offlineQueueStoreProvider);
  return AppointmentViewmodel(usecase, offlineStore, ref.watch(socketServiceProvider));
});

final reviewViewModelProvider =
    StateNotifierProvider<ReviewViewmodel, ReviewState>((ref) {
  final usecase = ref.watch(reviewUsecaseProvider);
  return ReviewViewmodel(usecase);
});
