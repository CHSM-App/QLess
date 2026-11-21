// Smoke tests for the three large screens split in Wave 7 (F1): each must
// build, show its first frame and dispose cleanly. Written before the split
// and run unchanged after it. No backend here (HTTP answers 400 in tests), so
// these cover building and disposing, not data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qless/presentation/doctor/screens/doctor_registration.dart';
import 'package:qless/presentation/doctor/screens/home_screen.dart';
import 'package:qless/presentation/patient/screens/patient_home_screen.dart';

Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  // The test font draws every glyph as a full-width box, so text-heavy rows
  // report overflows that real fonts don't have. Those are ignored here; any
  // other error fails the test.
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);

  await tester.pumpWidget(ProviderScope(child: MaterialApp(home: screen)));
  await tester.pump(const Duration(milliseconds: 100));
}

// Replace the screen (runs its dispose) inside the same ProviderScope, as
// navigation does in the app, and let delayed work finish: a dispose that
// throws or a timer that is never cancelled fails the test.
Future<void> disposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: SizedBox())));
  await tester.pump(const Duration(minutes: 1));
}

void main() {
  testWidgets('doctor registration builds step 1 and disposes', (tester) async {
    await pumpScreen(tester, const DoctorProfileSetupScreen());
    expect(find.byType(DoctorProfileSetupScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
    await disposeScreen(tester);
  });

  testWidgets('doctor home builds and disposes', (tester) async {
    await pumpScreen(tester, const QueueHomePage());
    expect(find.byType(QueueHomePage), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    await disposeScreen(tester);
  });

  testWidgets('patient home builds and disposes', (tester) async {
    await pumpScreen(
      tester,
      HomeScreen(onToggleTheme: () {}, themeMode: ThemeMode.light, onTabChange: (_) {}),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    await disposeScreen(tester);
  });
}
