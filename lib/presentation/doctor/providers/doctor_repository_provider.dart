import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/dio_provider.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/data/repositories/doctor_login_impl.dart';
import 'package:qless/data/repositories/doctor_settings_impl.dart';
import 'package:qless/domain/repository/doctor_login_repo.dart';
import 'package:qless/domain/repository/doctor_settings_repo.dart';

final doctorLoginRepositoryProvider = Provider<DoctorLoginRepository>((ref) {
  final dio = ref.watch(dioProvider).value!;
  final api = ApiService(dio);
  return DoctorLoginImpl(api);
});


final doctorSettingsRepositoryProvider = Provider<DoctorSettingsRepo>((ref) {
  final dio = ref.watch(dioProvider).value!;
  final api = ApiService(dio);
  return DoctorSettingsImpl(api);
});