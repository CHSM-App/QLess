import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/dio_provider.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/data/repositories/appointment_impl.dart';
import 'package:qless/data/repositories/doctors_impl.dart';
import 'package:qless/data/repositories/favorite_impl.dart';
import 'package:qless/data/repositories/family_impl.dart';
import 'package:qless/data/repositories/patient_login_impl.dart';
import 'package:qless/data/repositories/review_impl.dart';
import 'package:qless/domain/repository/appointment_repo.dart';
import 'package:qless/domain/repository/doctors_repo.dart';
import 'package:qless/domain/repository/favorite_repo.dart';
import 'package:qless/domain/repository/family_repo.dart';
import 'package:qless/domain/repository/patient_login_repo.dart';
import 'package:qless/domain/repository/review_repo.dart';

final patientLoginRepositoryProvider = Provider<PatientLoginRepository>((ref) {
  final dio = ref.watch(dioProvider).value!;
  final api = ApiService(dio);
  return PatientLoginImpl(api);
});


final doctorsRepositoryProvider = Provider<DoctorsRepository>((ref) {
  final dio = ref.watch(dioProvider).value!;
  final api = ApiService(dio);
  return DoctorsImpl(api);
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  final dio = ref.watch(dioProvider).value!;
  final api = ApiService(dio);
  return FamilyImpl(api);
});

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  final dio = ref.watch(dioProvider).value!;
  final api = ApiService(dio);
  return FavoriteImpl(api);
});

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  final dio = ref.watch(dioProvider).value!;
  final api = ApiService(dio);
  return AppointmentImpl(api);
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final dio = ref.watch(dioProvider).value!;
  final api = ApiService(dio);
  return ReviewImpl(api);
});

