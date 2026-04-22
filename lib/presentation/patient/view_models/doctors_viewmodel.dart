import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/usecase/doctors_usecase.dart';

class DoctorsState {
  final List<DoctorDetails> doctors;
  final List<DoctorAvailabilityModel> doctorAvailabilities;
  final bool isLoading;

  DoctorsState({
    required this.doctors,
    required this.doctorAvailabilities,
    required this.isLoading,
  });

  DoctorsState copyWith({
    List<DoctorDetails>? doctors,
    bool? isLoading,
    List<DoctorAvailabilityModel>? doctorAvailabilities,
  }) {
    return DoctorsState(
      doctors: doctors ?? this.doctors,
      doctorAvailabilities: doctorAvailabilities ?? this.doctorAvailabilities,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DoctorsViewmodel extends StateNotifier<DoctorsState> {
  final DoctorsUseCase doctorsUseCase;

  DoctorsViewmodel(this.doctorsUseCase)
    : super(
        DoctorsState(doctors: [], doctorAvailabilities: [], isLoading: false),
      );

  Future<void> fetchDoctors(int patientID) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);
    try {
      final doctors = await doctorsUseCase.fetchDoctors(patientID);
      state = state.copyWith(doctors: doctors, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> getDoctorAvailability(int doctorId) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);
    try {
      final availability = await doctorsUseCase.getDoctorAvailability(doctorId);
      state = state.copyWith(
        doctorAvailabilities: availability,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}
