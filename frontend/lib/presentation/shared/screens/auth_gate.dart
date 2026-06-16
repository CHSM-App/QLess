import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_bottom_nav.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/patient_bottom_nav.dart';
import 'package:qless/presentation/shared/screens/continue_as.dart';

/// Startup gate — no splash. Checks stored tokens and routes directly:
/// logged-in doctor/patient land on their dashboard, everyone else on the
/// role-select (login) screen. Replaces the old QlessSplashScreen.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    await ref.read(tokenProvider.notifier).loadTokens();
    final tokenState = ref.read(tokenProvider);
    if (!mounted) return;

    Widget target;
    if (tokenState.isLoggedIn && (tokenState.roleId == 1 || tokenState.roleId == 3)) {
      await ref.read(doctorLoginViewModelProvider.notifier).loadFromStorage();
      // Receptionist restart: if doctor mobile isn't in storage yet (first login
      // had the clinic_id bug), fall back to stored recep_clinic_id.
      if (tokenState.roleId == 3) {
        final doctorMobile = ref.read(doctorLoginViewModelProvider).mobile;
        if (doctorMobile == null || doctorMobile.trim().isEmpty) {
          final clinicId = await TokenStorage.getValue('recep_clinic_id');
          final doctorIdStr = await TokenStorage.getValue('recep_doctor_id');
          final doctorId = int.tryParse(doctorIdStr ?? '');
          await ref
              .read(doctorLoginViewModelProvider.notifier)
              .loadDoctorProfileForReceptionist(
                clinicId: clinicId,
                doctorId: doctorId,
              );
        }
        // Ensure receptionist's own name is in state (not doctor's name)
        final recepName = await TokenStorage.getValue('recep_name');
        if (recepName != null) {
          ref.read(receptionistLoginViewModelProvider.notifier).setName(recepName);
        }
      }
      target = const DoctorBottomNav();
    } else if (tokenState.isLoggedIn && tokenState.roleId == 2) {
      await ref
          .read(patientLoginViewModelProvider.notifier)
          .loadFromStoragePatient();
      patientShellKey = GlobalKey<PatientBottomNavState>();
      target = PatientBottomNav(
        key: patientShellKey,
        onToggleTheme: () {},
        themeMode: ThemeMode.light,
      );
    } else {
      target = const ContinueAsScreen();
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
