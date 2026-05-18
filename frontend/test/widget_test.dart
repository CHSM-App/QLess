import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qless/presentation/shared/screens/continue_as.dart';

void main() {
  testWidgets('Splash screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: const ContinueAsScreen(),
        ),
      ),
    );

    expect(find.byType(ContinueAsScreen), findsOneWidget);
  });

  testWidgets('Splash screen shows role buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: const ContinueAsScreen(),
        ),
      ),
    );

    expect(find.text('Continue as Doctor'), findsOneWidget);
    expect(find.text('Continue as Patient'), findsOneWidget);
  });
}
