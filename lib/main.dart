
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/presentation/shared/controllers/sync_controller.dart';
import 'package:qless/presentation/shared/screens/splash_screen.dart';
 
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();//Global navigator access
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =GlobalKey<ScaffoldMessengerState>();//Global scaffold messenger access

void main() async {
    WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await container.read(tokenProvider.notifier).loadTokens();
  runApp(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          ref.read(syncControllerProvider);
          return const HealthcareApp();
        },
      ),
    ),
  );
}

class HealthcareApp extends StatelessWidget {
  const HealthcareApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
     title: 'HealthConnect',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
          builder: (context, child) {
      return Stack(
        children: [
          child!,
          Padding(
            padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight),
            child: const Align(
              alignment: Alignment.bottomCenter,
              // child: NetworkBanner(),
            ),
          ),
        ],
      );
    },
      themeMode: ThemeMode.light,
      home: const SplashScreen(), // ✅ Auto-login logic
    );
  }
}
