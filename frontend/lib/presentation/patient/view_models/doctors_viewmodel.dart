import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/doctor_leave_model.dart';
import 'package:qless/domain/usecase/doctors_usecase.dart';

class DoctorsState {
  final List<DoctorDetails> doctors;
  final List<DoctorAvailabilityModel> doctorAvailabilities;
  final List<LeaveRange> leaveRanges;
  final bool isLoading;

  DoctorsState({
    required this.doctors,
    required this.doctorAvailabilities,
    required this.isLoading,
    this.leaveRanges = const [],
  });

  DoctorsState copyWith({
    List<DoctorDetails>? doctors,
    bool? isLoading,
    List<DoctorAvailabilityModel>? doctorAvailabilities,
    List<LeaveRange>? leaveRanges,
  }) {
    return DoctorsState(
      doctors: doctors ?? this.doctors,
      doctorAvailabilities: doctorAvailabilities ?? this.doctorAvailabilities,
      leaveRanges: leaveRanges ?? this.leaveRanges,
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
    // Clear the previous doctor's schedule so a new profile doesn't briefly
    // render stale availability while this fetch is in flight.
    state = state.copyWith(isLoading: true, doctorAvailabilities: const []);
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

  /// Active future leave ranges for the doctor — used to grey out
  /// unavailable dates in the booking calendar. Runs independently of
  /// [isLoading] so it doesn't race with availability loading.
  Future<void> getDoctorLeaveDates(int doctorId) async {
    try {
      final ranges = await doctorsUseCase.getDoctorLeaveDates(doctorId);
      state = state.copyWith(leaveRanges: ranges);
    } catch (e) {
      // non-fatal: server-side guard still blocks booking on leave dates
      state = state.copyWith(leaveRanges: const []);
    }
  }
}
