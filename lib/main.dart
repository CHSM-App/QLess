import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/firebase_options.dart';
import 'package:qless/presentation/shared/controllers/sync_controller.dart';
import 'package:qless/presentation/shared/screens/continue_as.dart';
import 'package:qless/presentation/shared/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>(); //Global navigator access
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(); //Global scaffold messenger access

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for important notifications.',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  await _setupNotifications();

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
              padding: const EdgeInsets.only(
                bottom: kBottomNavigationBarHeight,
              ),
              child: const Align(
                alignment: Alignment.bottomCenter,
                // child: NetworkBanner(),
              ),
            ),
          ],
        );
      },
      themeMode: ThemeMode.light,
      home: QlessSplashScreen(
        nextScreen: const SplashScreen(), // your existing role-select screen
      ), // ✅ Auto-login logic
    );
  }
}

Future<void> _setupNotifications() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await _localNotifications.initialize(initSettings);

  final androidPlugin = _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_androidChannel);

  if (defaultTargetPlatform == TargetPlatform.android) {
    final status = await Permission.notification.request();
    debugPrint('Notification permission status: $status');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title']?.toString();
    final body = notification?.body ?? data['body']?.toString();

    if (title == null && body == null) {
      return;
    }

    _localNotifications.show(
      notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title ?? 'Notification',
      body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: notification?.android?.smallIcon ?? '@mipmap/ic_launcher',
        ),
      ),
    );
  });
}
