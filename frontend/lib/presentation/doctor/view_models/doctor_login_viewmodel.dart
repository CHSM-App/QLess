import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/database/offline_queue_store.dart';
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/otp_response.dart';
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
  final AsyncValue<List<DoctorDetails>>? clinicsList;

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
    this.clinicsList,
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
    bool clearError = false,
    AsyncValue<List<DoctorDetails>>? phoneCheckResult,
    AsyncValue<List<Medicine>>? medicines,
    AsyncValue<List<Medicine>>? medicineTypes,
    AsyncValue<List<DoctorDetails>>? clinicsList,
  }) {
    return DoctorLoginState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
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
      clinicsList: clinicsList ?? this.clinicsList,
    );
  }
}

String _extractErrorMessage(Object e) {
  if (e is DioException) {
    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      final msg = data['error']?.toString() ?? data['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    if (e.message != null && e.message!.isNotEmpty) return e.message!;
  }
  return e.toString();
}

class DoctorLoginViewmodel extends StateNotifier<DoctorLoginState> {
  final DoctorLoginUsecase usecase;
  final OfflineQueueStore offlineStore;

  DoctorLoginViewmodel(this.usecase, this.offlineStore)
      : super(const DoctorLoginState()) {
    loadFromStorage();
  }

  Future<void> loadFromStorage() async {
    final doctorName = await TokenStorage.getValue('doctor_name');
    final name = doctorName ?? await TokenStorage.getValue('name');
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

    // Only seed the lightweight storage profile when we don't already hold
    // richer details from checkPhoneDoctor — otherwise this would clobber the
    // full profile (qualification, fee, address, gender, …) with half the
    // fields and the edit screen would show blanks for the rest.
    final hasFullDetails = state.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );
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
      phoneCheckResult: hasFullDetails
          ? state.phoneCheckResult
          : AsyncValue.data([
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

  // Future<void> addDoctorDetails(DoctorDetails doctorLogin) async {
  //   state = state.copyWith(isLoading: true, error: null);
  //   try {
  //     await usecase.addDoctorDetails(doctorLogin);
  //     state = state.copyWith(isLoading: false);
  //   } catch (e) {
  //     state = state.copyWith(isLoading: false, error: e.toString());
  //   }
  // }

  Future<void> addDoctorDetails(
    DoctorDetails doctorLogin, {
    File? doctorImage,
    List<File>? clinicImages,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await usecase.addDoctorDetails(
        doctorLogin,
        doctorImage: doctorImage,
        clinicImages: clinicImages,
      );
      final dynamic rawDoctorId = result['doctor_id'];
      final dynamic rawClinicId = result['clinic_id'];
      final int? doctorId = rawDoctorId is int
          ? rawDoctorId
          : int.tryParse(rawDoctorId?.toString() ?? '');
      final String? clinicId = rawClinicId?.toString();
      if (clinicId != null &&
          clinicId.trim().isNotEmpty &&
          clinicId.trim().toLowerCase() != 'null') {
        await TokenStorage.saveValue('clinic_id', clinicId);
      }
      state = state.copyWith(
        isLoading: false,
        doctorId: doctorId, // stored on state for the screen to read
        clinicId: clinicId,
        clearError: true,
      );
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        final data = e.response!.data as Map;
        final dynamic rawDoctorId = data['doctor_id'];
        final int? doctorId = rawDoctorId is int
            ? rawDoctorId
            : int.tryParse(rawDoctorId?.toString() ?? '');
        if (doctorId != null && doctorId > 0) {
          final String? clinicId = data['clinic_id']?.toString();
          if (clinicId != null &&
              clinicId.trim().isNotEmpty &&
              clinicId.trim().toLowerCase() != 'null') {
            await TokenStorage.saveValue('clinic_id', clinicId);
          }
          state = state.copyWith(
            isLoading: false,
            doctorId: doctorId,
            clinicId: clinicId,
            clearError: true,
          );
          return;
        }

        // Some backend flows create doctor/clinic records but still return 500
        // with { success: false, message: "Doctor creation failed" }.
        // Reconcile using mobile lookup so registration can proceed safely.
        final String rawMessage = (data['message'] ?? '').toString().toLowerCase();
        if (rawMessage.contains('doctor creation failed') &&
            (doctorLogin.mobile ?? '').trim().isNotEmpty) {
          try {
            final existing = await usecase.checkPhoneDoctor(
              doctorLogin.mobile!.trim(),
            );
            if (existing.isNotEmpty) {
              final d = existing.first;
              if (d.clinicId != null &&
                  d.clinicId!.trim().isNotEmpty &&
                  d.clinicId!.trim().toLowerCase() != 'null') {
                await TokenStorage.saveValue('clinic_id', d.clinicId!);
              }
              state = state.copyWith(
                isLoading: false,
                doctorId: d.doctorId,
                clinicId: d.clinicId,
                clearError: true,
              );
              return;
            }
          } catch (_) {
            // fall through to original error handling
          }
        }
      }
      state = state.copyWith(isLoading: false, error: _extractErrorMessage(e));
    }
  }

  Future<void> checkPhoneDoctor(String mobile) async {
    // Offline-first: keep previously-loaded details visible while refreshing.
    // A failed/offline refresh must not blank out the profile & edit screens.
    final hadData = state.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );
    state = state.copyWith(
      phoneCheckResult:
          hadData ? state.phoneCheckResult : const AsyncValue.loading(),
      error: null,
    );
    try {
      final result = await usecase.checkPhoneDoctor(mobile);
      final existingClinicId = state.clinic_id;
      if (existingClinicId != null) {
        // Clinic already selected via picker.
        // Update personal fields from API, preserve clinic fields from selectClinic.
        final d = result.first;
        final currentList = state.phoneCheckResult.maybeWhen(
          data: (l) => l,
          orElse: () => <DoctorDetails>[],
        );
        final currentFirst = currentList.isNotEmpty ? currentList.first : null;
        final updatedFirst = DoctorDetails(
          // Personal fields from checkPhoneDoctor (has specialization, qualification etc.)
          doctorId:       d.doctorId,
          name:           d.name,
          email:          d.email,
          mobile:         d.mobile,
          qualification:  d.qualification,
          licenseNo:      d.licenseNo,
          experience:     d.experience,
          specialization: d.specialization,
          image:          d.image,
          roleId:         d.roleId,
          Token:          d.Token,
          genderId:       d.genderId,
          isverified:     d.isverified,
          leadTime:       d.leadTime,
          qStartSection:  d.qStartSection,
          // Clinic fields preserved from selectClinic merge
          clinicId:        currentFirst?.clinicId      ?? existingClinicId,
          clinicName:      currentFirst?.clinicName    ?? state.clinic_name,
          clinicAddress:   currentFirst?.clinicAddress,
          latitude:        currentFirst?.latitude,
          longitude:       currentFirst?.longitude,
          consultationFee: currentFirst?.consultationFee,
          websiteName:     currentFirst?.websiteName,
          clinicEmail:     currentFirst?.clinicEmail,
          clinicContact:   currentFirst?.clinicContact,
          imageUrl:        currentFirst?.imageUrl,
        );
        final updatedList = currentList.isNotEmpty
            ? [updatedFirst, ...currentList.skip(1)]
            : [updatedFirst];
        state = state.copyWith(
          doctorId:       d.doctorId,
          name:           d.name,
          mobile:         d.mobile,
          email:          d.email,
          roleId:         d.roleId?.toString(),
          token:          d.Token,
          leadTimeMinutes: d.leadTime,
          phoneCheckResult: AsyncValue.data(updatedList),
        );
        if (d.name != null) await TokenStorage.saveValue('name', d.name!);
      } else {
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
        if (d.name != null) await TokenStorage.saveValue('name', d.name!);
        if (d.clinicName != null) {
          await TokenStorage.saveValue('clinic_name', d.clinicName!);
        }
        if (d.clinicId != null &&
            d.clinicId!.trim().isNotEmpty &&
            d.clinicId!.trim().toLowerCase() != 'null' &&
            d.clinicId!.trim() != '0') {
          await TokenStorage.saveValue('clinic_id', d.clinicId!.trim());
        }
      }
    } catch (e, st) {
      state = state.copyWith(
        // Preserve the cached details on failure; only surface an error state
        // when we never had any data to show.
        phoneCheckResult:
            hadData ? state.phoneCheckResult : AsyncValue.error(e, st),
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
      // Keep the real error text so the UI can tell a network failure apart
      // from a genuine server error and show "No internet connection".
      final message = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isLoading: false, error: message);
      return {"success": 0, "message": message};
    }
  }

  Future<void> fetchMedicineTypes() async {
    state = state.copyWith(
      medicineTypes: const AsyncValue.loading(),
      error: null,
    );
    try {
      final result = await usecase.fetchMedicineTypes();
      state = state.copyWith(medicineTypes: AsyncValue.data(result));
    } catch (e, st) {
      state = state.copyWith(medicineTypes: AsyncValue.error(e, st));
    }
  }

  Future<void> fetchAllMedicines(int doctorId) async {
    state = state.copyWith(medicines: const AsyncValue.loading(), error: null);
    try {
      final result = await usecase.fetchAllMedicines(doctorId);
      // Cache the catalog so it's available for offline prescriptions.
      try {
        await offlineStore.cacheMedicines(doctorId, result);
      } catch (_) {}
      state = state.copyWith(medicines: AsyncValue.data(result));
    } catch (e) {
      // Network down — serve the cached catalog instead of an error state
      // (which would otherwise crash the prescription screen on `.value`).
      try {
        final cached = await offlineStore.getCachedMedicines(doctorId);
        state = state.copyWith(medicines: AsyncValue.data(cached));
      } catch (_) {
        state = state.copyWith(medicines: const AsyncValue.data([]));
      }
    }
  }

  void removeMedicineLocally(int medicineId) {
    final current = state.medicines;
    if (current is AsyncData<List<Medicine>>) {
      final updated = current.value
          .where((m) => m.medicineId != medicineId)
          .toList();
      state = state.copyWith(medicines: AsyncValue.data(updated));
    }
  }

  Future<List<Medicine>> getMedicineSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      return await usecase.getMedicineSuggestions(query.trim());
    } catch (_) {
      return [];
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


  Future<List<String>> fetchClinicGallery(String clinicId) async {
    try {
      return await usecase.fetchClinicGallery(clinicId);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> deleteClinicGallery(
    String clinicId,
    List<String> imageUrls,
  ) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final response = await usecase.deleteClinicGallery(clinicId, imageUrls);
      state = state.copyWith(isLoading: false);
      if (response is Map<String, dynamic>) {
        return response;
      }
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {"success": true, "message": "Images deleted"};
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return {"success": false, "message": e.toString()};
    }
  }

  Future<void> updateLeadTime(DoctorDetails doctor) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

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
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  
  Future<OtpResponse> sendOtp(OtpResponse payload) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await usecase.sendOtp(payload);
      state = state.copyWith(isLoading: false);
      return response;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return OtpResponse(status: 0, message: "Something went wrong");
    }
  }

  Future<OtpResponse> verifyOtp(OtpResponse payload) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await usecase.verifyOtp(payload);
      state = state.copyWith(isLoading: false);
      return response;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return OtpResponse(status: 0, message: "Something went wrong");
    }
  }

  /// Receptionist login: loads linked doctor's full profile using clinic_id
  /// or doctor_id via the dedicated backend route (doctor_login_vw).
  Future<void> loadDoctorProfileForReceptionist({String? clinicId, int? doctorId}) async {
    try {
      debugPrint('[RecepDebug] loadDoctorProfile clinicId=$clinicId doctorId=$doctorId');
      final doctors = await usecase.getDoctorProfileByClinic(clinicId: clinicId, doctorId: doctorId);
      debugPrint('[RecepDebug] doctors returned: ${doctors.length}');
      if (doctors.isEmpty) return;
      final d = doctors.first;
      debugPrint('[RecepDebug] d.clinicId=${d.clinicId} d.clinicName=${d.clinicName}');

      // Preserve any clinic the user already selected (saved via selectClinic).
      // On first login state.clinic_id is null → use API value.
      // On app restart state.clinic_id is loaded from storage → keep it.
      final existingClinicId   = state.clinic_id;
      final existingClinicName = state.clinic_name;
      final resolvedClinicId   = existingClinicId   ?? d.clinicId;
      final resolvedClinicName = existingClinicName ?? d.clinicName;

      state = state.copyWith(
        doctorId: d.doctorId,
        name: d.name,
        mobile: d.mobile,
        email: d.email,
        roleId: d.roleId?.toString(),
        token: d.Token,
        clinicId: resolvedClinicId,
        clinic_name: resolvedClinicName,
        leadTimeMinutes: d.leadTime,
        phoneCheckResult: AsyncValue.data(doctors),
      );
      if (d.doctorId != null && d.doctorId! > 0) await TokenStorage.saveValue('doctor_id', d.doctorId.toString());
      if (d.name != null) await TokenStorage.saveValue('doctor_name', d.name!);
      if (d.mobile != null) await TokenStorage.saveValue('recep_doctor_mobile', d.mobile!);
      // Only write clinic to storage when there was no previously saved selection.
      if (existingClinicId == null) {
        if (d.clinicId != null) await TokenStorage.saveValue('clinic_id', d.clinicId!);
        if (d.clinicName != null) await TokenStorage.saveValue('clinic_name', d.clinicName!);
      }
    } catch (e) {
      debugPrint('[RecepDebug] loadDoctorProfile ERROR: $e');
    }
  }

  Future<void> selectClinic(DoctorDetails clinic) async {
    // First, update clinic_id/name immediately so UI is responsive.
    state = state.copyWith(
      clinicId: clinic.clinicId,
      clinic_name: clinic.clinicName,
      leadTimeMinutes: clinic.leadTime,
    );
    if (clinic.clinicId != null) {
      await TokenStorage.saveValue('clinic_id', clinic.clinicId!);
    }
    if (clinic.clinicName != null) {
      await TokenStorage.saveValue('clinic_name', clinic.clinicName!);
    }

    // Build phoneCheckResult: personal fields from existing state (set by
    // checkPhoneDoctor / loadDoctorProfileForReceptionist), clinic fields from
    // picker selection (GetDoctorClinics returns full clinic row).
    final currentList = state.phoneCheckResult.maybeWhen(
      data: (l) => l,
      orElse: () => <DoctorDetails>[],
    );
    final personal = currentList.isNotEmpty ? currentList.first : null;
    final merged = DoctorDetails(
      doctorId:        personal?.doctorId      ?? state.doctorId,
      name:            personal?.name          ?? state.name,
      email:           personal?.email         ?? state.email,
      mobile:          personal?.mobile        ?? state.mobile,
      qualification:   personal?.qualification,
      licenseNo:       personal?.licenseNo,
      experience:      personal?.experience,
      specialization:  personal?.specialization,
      image:           personal?.image,
      roleId:          personal?.roleId,
      Token:           personal?.Token,
      genderId:        personal?.genderId,
      isverified:      personal?.isverified,
      leadTime:        clinic.leadTime ?? personal?.leadTime,
      qStartSection:   personal?.qStartSection,
      // Clinic fields from picker (GetDoctorClinics has full clinic row)
      clinicId:        clinic.clinicId,
      clinicName:      clinic.clinicName,
      clinicAddress:   clinic.clinicAddress,
      latitude:        clinic.latitude,
      longitude:       clinic.longitude,
      consultationFee: clinic.consultationFee,
      websiteName:     clinic.websiteName,
      clinicEmail:     clinic.clinicEmail,
      clinicContact:   clinic.clinicContact,
      imageUrl:        clinic.imageUrl,
    );
    final allClinics = state.clinicsList?.maybeWhen(
          data: (l) => l,
          orElse: () => <DoctorDetails>[],
        ) ??
        <DoctorDetails>[];
    final reordered = [
      merged,
      ...allClinics.where((c) => c.clinicId != clinic.clinicId),
    ];
    state = state.copyWith(
      leadTimeMinutes: merged.leadTime ?? state.leadTimeMinutes,
      phoneCheckResult: AsyncValue.data(reordered),
    );
  }

  Future<void> getDoctorClinics(int doctorId) async {
    state = state.copyWith(clinicsList: const AsyncValue.loading());
    try {
      final result = await usecase.getClinicsForDoctor(doctorId);
      state = state.copyWith(clinicsList: AsyncValue.data(result));
    } catch (e, st) {
      state = state.copyWith(clinicsList: AsyncValue.error(e, st));
    }
  }

  Future<bool> addClinic(DoctorDetails clinic, {List<File>? clinicImages}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await usecase.addClinic(clinic, clinicImages: clinicImages);
      state = state.copyWith(isLoading: false);
      if (clinic.doctorId != null) await getDoctorClinics(clinic.doctorId!);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractErrorMessage(e));
      return false;
    }
  }

  Future<bool> updateClinic(DoctorDetails clinic, {List<File>? clinicImages}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await usecase.updateClinic(clinic, clinicImages: clinicImages);
      state = state.copyWith(isLoading: false);
      if (clinic.doctorId != null) await getDoctorClinics(clinic.doctorId!);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractErrorMessage(e));
      return false;
    }
  }

  Future<bool> deleteClinic(String clinicId, int doctorId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await usecase.deleteClinic(clinicId, doctorId);
      state = state.copyWith(isLoading: false);
      await getDoctorClinics(doctorId);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractErrorMessage(e));
      return false;
    }
  }

  /// Called at receptionist login: fetches the linked doctor's data using
  /// clinic_id. If doctorId is provided, picks the matching doctor from the
  /// list (handles multi-doctor clinics). Falls back to first doctor.
  Future<void> fetchAndLoadDoctorByClinic(String clinicId, {int? doctorId}) async {
    try {
      final doctors = await usecase.fetchDoctorsByClinic(clinicId);
      if (doctors.isEmpty) return;
      final doctor = doctorId != null
          ? doctors.firstWhere(
              (d) => d.doctorId == doctorId,
              orElse: () => doctors.first,
            )
          : doctors.first;
      final doctorMobile = doctor.mobile;
      if (doctorMobile == null || doctorMobile.trim().isEmpty) return;
      await checkPhoneDoctor(doctorMobile.trim());
    } catch (_) {}
  }
}
