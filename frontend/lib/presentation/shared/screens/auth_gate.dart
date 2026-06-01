import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
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
    if (tokenState.isLoggedIn && tokenState.roleId == 1) {
      await ref.read(doctorLoginViewModelProvider.notifier).loadFromStorage();
      target = const DoctorBottomNav();
    } else if (tokenState.isLoggedIn && tokenState.roleId == 2) {
      await ref
          .read(patientLoginViewModelProvider.notifier)
          .loadFromStoragePatient();
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
