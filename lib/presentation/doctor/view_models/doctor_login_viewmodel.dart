import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/usecase/doctor_login_usecase.dart';

class DoctorLoginState {
  final bool isLoading;
  final String? error;
  final int? doctorId;
  final String? name;
  final String? mobile;
  final String? email;
  final String? roleId;
  final String? token;
  final String? clinic_name;
  final String? clinic_id;
  final int? leadTimeMinutes;
  final AsyncValue<List<DoctorDetails>> phoneCheckResult;
  final AsyncValue<List<Medicine>>? medicines;
  final AsyncValue<List<Medicine>>? medicineTypes;

  const DoctorLoginState({
    this.isLoading = false,
    this.error,
    this.name,
    this.mobile,
    this.email,
    this.roleId,
    this.token,
    this.doctorId,
    this.clinic_id,
    this.clinic_name,
    this.leadTimeMinutes,
    this.phoneCheckResult = const AsyncValue.data([]),
    this.medicineTypes,
    this.medicines,
  });

  DoctorLoginState copyWith({
    bool? isLoading,
    String? error,
    String? name,
    String? mobile,
    String? email,
    String? roleId,
    String? token,
    int? doctorId,
    String? clinicId,
    String? clinic_name,
    int? leadTimeMinutes,
    AsyncValue<List<DoctorDetails>>? phoneCheckResult,
    AsyncValue<List<Medicine>>? medicines,
    AsyncValue<List<Medicine>>? medicineTypes,
  }) {
    return DoctorLoginState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      doctorId: doctorId ?? this.doctorId,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      roleId: roleId ?? this.roleId,
      token: token ?? this.token,
      clinic_id: clinicId ?? this.clinic_id,
      leadTimeMinutes: leadTimeMinutes ?? this.leadTimeMinutes,
      clinic_name: clinic_name ?? this.clinic_name,
      phoneCheckResult: phoneCheckResult ?? this.phoneCheckResult,
      medicineTypes: medicineTypes ?? this.medicineTypes,
      medicines: medicines ?? this.medicines,
    );
  }
}

class DoctorLoginViewmodel extends StateNotifier<DoctorLoginState> {
  final DoctorLoginUsecase usecase;

  DoctorLoginViewmodel(this.usecase) : super(const DoctorLoginState()) {
    loadFromStorage();
  }

  Future<void> loadFromStorage() async {
    final name = await TokenStorage.getValue('name');
    final mobile = await TokenStorage.getValue('mobile');
    final email = await TokenStorage.getValue('email');
    final roleId = await TokenStorage.getValue('role_id');
    final token = await TokenStorage.getValue('token');
    final doctorIdStr = await TokenStorage.getValue('doctor_id');
    final doctorId = int.tryParse(doctorIdStr ?? '0') ?? 0;
    final clinicName = await TokenStorage.getValue('clinic_name');
    final clinicId = await TokenStorage.getValue('clinic_id');
    final leadTime = await TokenStorage.getValue('q_start_before');
    final leadTimeMinutes = int.tryParse(leadTime ?? '');

    state = state.copyWith(
      clinicId: clinicId,
      doctorId: doctorId,
      name: name,
      mobile: mobile,
      email: email,
      roleId: roleId,
      clinic_name: clinicName,
      token: token,
      leadTimeMinutes: leadTimeMinutes,
      phoneCheckResult: AsyncValue.data([
        DoctorDetails(
          doctorId: doctorId,
          name: name,
          mobile: mobile,
          email: email,
          roleId: roleId != null ? int.tryParse(roleId) : null,
          clinicName: clinicName,
          Token: token,
          clinicId: clinicId,
          leadTime: leadTimeMinutes,
        ),
      ]),
    );
  }

  Future<void> addDoctorDetails(DoctorDetails doctorLogin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await usecase.addDoctorDetails(doctorLogin);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> checkPhoneDoctor(String mobile) async {
    state = state.copyWith(
      phoneCheckResult: const AsyncValue.loading(),
      error: null,
    );
    try {
      final result = await usecase.checkPhoneDoctor(mobile);
      if (result.isNotEmpty) {
        final d = result.first;
        state = state.copyWith(
          doctorId: d.doctorId,
          name: d.name,
          mobile: d.mobile,
          email: d.email,
          roleId: d.roleId?.toString(),
          token: d.Token,
          clinicId: d.clinicId,
          clinic_name: d.clinicName,
          leadTimeMinutes: d.leadTime,
          phoneCheckResult: AsyncValue.data(result),
        );
      } else {
        state = state.copyWith(phoneCheckResult: AsyncValue.data(result));
      }
    } catch (e, st) {
      state = state.copyWith(
        phoneCheckResult: AsyncValue.error(e, st),
        error: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> addMedicine(Medicine medicine) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final response = await usecase.addMedicine(medicine);
      state = state.copyWith(isLoading: false);
      return response;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to add medicine');
      return {"success": 0, "message": "Failed to add medicine"};
    }
  }

  Future<void> fetchMedicineTypes() async {
    state = state.copyWith(
      medicineTypes: const AsyncValue.loading(),
      error: null,
    );
    try {
      final result = await usecase.fetchMedicineTypes();
      state = state.copyWith(
        medicineTypes: AsyncValue.data(result),
      );
    } catch (e, st) {
      state = state.copyWith(
        medicineTypes: AsyncValue.error(e, st),
      );
    }
  }

  Future<void> fetchAllMedicines(int doctorId) async {
    state = state.copyWith(
      medicines: const AsyncValue.loading(),
      error: null,
    );
    try {
      final result = await usecase.fetchAllMedicines(doctorId);
      state = state.copyWith(
        medicines: AsyncValue.data(result),
      );
    } catch (e, st) {
      state = state.copyWith(
        medicines: AsyncValue.error(e, st),
      );
    }
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    state = const DoctorLoginState();
  }

  Future<List<DoctorDetails>> mobileExistDoctor(String mobile) async {
    try {
      return await usecase.mobileExistDoctor(mobile);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  Future<void> updateLeadTime(DoctorDetails doctor) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await usecase.updateLeadTime(doctor);

      final updatedPhoneCheckResult = state.phoneCheckResult.maybeWhen(
        data: (list) {
          final updatedList = list
              .map(
                (item) => item.doctorId == doctor.doctorId
                    ? DoctorDetails(
                        queueLength: item.queueLength,
                        doctorId: item.doctorId,
                        name: item.name,
                        email: item.email,
                        mobile: item.mobile,
                        qualification: item.qualification,
                        licenseNo: item.licenseNo,
                        experience: item.experience,
                        specialization: item.specialization,
                        image: item.image,
                        roleId: item.roleId,
                        Token: item.Token,
                        clinicId: item.clinicId,
                        clinicName: item.clinicName,
                        clinicAddress: item.clinicAddress,
                        latitude: item.latitude,
                        longitude: item.longitude,
                        consultationFee: item.consultationFee,
                        websiteName: item.websiteName,
                        clinicEmail: item.clinicEmail,
                        clinicContact: item.clinicContact,
                        imageUrl: item.imageUrl,
                        genderId: item.genderId,
                        leadTime: doctor.leadTime,
                      )
                    : item,
              )
              .toList();
          return AsyncValue.data(updatedList);
        },
        orElse: () => state.phoneCheckResult,
      );

      state = state.copyWith(
        isLoading: false,
        leadTimeMinutes: doctor.leadTime,
        phoneCheckResult: updatedPhoneCheckResult,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}
