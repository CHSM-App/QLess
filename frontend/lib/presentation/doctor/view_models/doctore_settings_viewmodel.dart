


import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_leave_model.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/domain/usecase/doctor_settings_usecase.dart';

/// Result of an add-leave attempt.
enum AddLeaveResult { success, needConfirm, error }

class ScheduleConflict {
  final String day;
  final int slotId;
  final int futureAppointments;

  ScheduleConflict({
    required this.day,
    required this.slotId,
    required this.futureAppointments,
  });

  factory ScheduleConflict.fromJson(Map<String, dynamic> json) =>
      ScheduleConflict(
        day: json['day'] as String? ?? '',
        slotId: (json['slot_id'] as num?)?.toInt() ?? 0,
        futureAppointments:
            (json['future_appointments'] as num?)?.toInt() ?? 0,
      );
}

class DoctorSettingsState {
  final bool isLoading;
  final String errorMessage;
  final DoctorScheduleModel? doctorSchedule;
  final List<ScheduleConflict>? pendingConflicts;

  /// Set when the server rejects the save because TODAY already has
  /// bookings on a slot being removed/retimed (use Leave / per-appointment).
  final String? todayBlockedMessage;

  // ── Leave / Sutti ──────────────────────────────────────────────
  final List<DoctorLeaveModel> leaves;
  final bool isLeaveBusy;

  const DoctorSettingsState({
    this.isLoading = false,
    this.errorMessage = '',
    this.doctorSchedule,
    this.pendingConflicts,
    this.todayBlockedMessage,
    this.leaves = const [],
    this.isLeaveBusy = false,
  });

  DoctorSettingsState copyWith({
    bool? isLoading,
    String? errorMessage,
    DoctorScheduleModel? doctorSchedule,
    List<ScheduleConflict>? pendingConflicts,
    bool clearConflicts = false,
    String? todayBlockedMessage,
    bool clearTodayBlocked = false,
    List<DoctorLeaveModel>? leaves,
    bool? isLeaveBusy,
  }) {
    return DoctorSettingsState(
      doctorSchedule: doctorSchedule ?? this.doctorSchedule,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      pendingConflicts: clearConflicts
          ? null
          : (pendingConflicts ?? this.pendingConflicts),
      todayBlockedMessage: clearTodayBlocked
          ? null
          : (todayBlockedMessage ?? this.todayBlockedMessage),
      leaves: leaves ?? this.leaves,
      isLeaveBusy: isLeaveBusy ?? this.isLeaveBusy,
    );
  }
}

class DoctorSettingsViewModel extends StateNotifier<DoctorSettingsState> {
  final DoctorSettingsUsecase doctorSettingsUsecase;

  DoctorSettingsViewModel(this.doctorSettingsUsecase)
      : super(const DoctorSettingsState());

  /// Returns true when save completed; false when a 409 conflict was raised
  /// (caller should inspect `state.pendingConflicts` and prompt the user).
  Future<bool> saveDoctorSchedule(
    DoctorScheduleModel doctorSchedule, {
    bool force = false,
    String action = 'cancel',
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: '',
      clearConflicts: true,
      clearTodayBlocked: true,
    );
    try {
      final result = await doctorSettingsUsecase.saveDoctorSchedule(
        doctorSchedule,
        force: force,
        action: action,
      );
      debugPrint('Doctor schedule saved successfully: ${result?['message']}');
      return true;
    } on DioException catch (e) {
      // 409 = future appointments exist on slots being removed
      if (e.response?.statusCode == 409) {
        final data = e.response?.data as Map<String, dynamic>?;
        // Hard block: TODAY already has bookings on a slot being changed.
        if (data?['today_blocked'] == true) {
          state = state.copyWith(
            todayBlockedMessage: data?['message']?.toString() ??
                "You have bookings today. Today's schedule can't be "
                    'changed here — use Leave or reschedule from the queue.',
          );
          return false;
        }
        final raw = (data?['conflicts'] as List?) ?? const [];
        final conflicts = raw
            .whereType<Map<String, dynamic>>()
            .map(ScheduleConflict.fromJson)
            .toList();
        state = state.copyWith(pendingConflicts: conflicts);
        return false;
      }
      debugPrint('Error saving doctor schedule: $e');
      final data = e.response?.data;
      final msg = data is Map<String, dynamic>
          ? (data['message']?.toString() ?? 'Failed to save schedule')
          : 'Failed to save schedule';
      state = state.copyWith(errorMessage: msg);
      return false;
    } catch (e) {
      debugPrint('Error saving doctor schedule: $e');
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void clearConflicts() {
    state = state.copyWith(clearConflicts: true);
  }

  Future<void> getDoctorSchedule(int doctorId) async {
    state = state.copyWith(isLoading: true, errorMessage: '');
    try {
      final schedule = await doctorSettingsUsecase.getDoctorSchedule(doctorId);
      state = state.copyWith(doctorSchedule: schedule);
    } catch (e) {
      debugPrint('Error fetching doctor schedule: $e');
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // ── Leave / Sutti ────────────────────────────────────────────────────────

  Future<void> getDoctorLeaves(int doctorId) async {
    state = state.copyWith(isLeaveBusy: true);
    try {
      final leaves = await doctorSettingsUsecase.getDoctorLeaves(doctorId);
      state = state.copyWith(leaves: leaves);
    } catch (e) {
      debugPrint('Error fetching doctor leaves: $e');
    } finally {
      state = state.copyWith(isLeaveBusy: false);
    }
  }

  /// Returns the result plus the count of appointments that exist in the
  /// range. When the result is [AddLeaveResult.needConfirm] the caller should
  /// confirm with the doctor, then call again with `force: true`.
  Future<(AddLeaveResult, int)> addDoctorLeave({
    required int doctorId,
    required String fromDate,
    required String toDate,
    String? reason,
    bool force = false,
  }) async {
    state = state.copyWith(isLeaveBusy: true, errorMessage: '');
    try {
      await doctorSettingsUsecase.addDoctorLeave(
        doctorId: doctorId,
        fromDate: fromDate,
        toDate: toDate,
        reason: reason,
        force: force,
      );
      await getDoctorLeaves(doctorId);
      return (AddLeaveResult.success, 0);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final data = e.response?.data as Map<String, dynamic>?;
        final affected =
            (data?['affected_appointments'] as num?)?.toInt() ?? 0;
        return (AddLeaveResult.needConfirm, affected);
      }
      final data = e.response?.data;
      final msg = data is Map<String, dynamic>
          ? (data['message']?.toString() ?? 'Failed to apply leave')
          : 'Failed to apply leave';
      state = state.copyWith(errorMessage: msg);
      return (AddLeaveResult.error, 0);
    } catch (e) {
      debugPrint('Error applying leave: $e');
      state = state.copyWith(errorMessage: e.toString());
      return (AddLeaveResult.error, 0);
    } finally {
      state = state.copyWith(isLeaveBusy: false);
    }
  }

  Future<bool> cancelDoctorLeave({
    required int doctorId,
    required int leaveId,
  }) async {
    state = state.copyWith(isLeaveBusy: true, errorMessage: '');
    try {
      await doctorSettingsUsecase.cancelDoctorLeave(
        doctorId: doctorId,
        leaveId: leaveId,
      );
      await getDoctorLeaves(doctorId);
      return true;
    } catch (e) {
      debugPrint('Error cancelling leave: $e');
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(isLeaveBusy: false);
    }
  }
}
