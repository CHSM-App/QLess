import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/firebase_options.dart';
import 'package:qless/presentation/patient/providers/notification_provider.dart';
import 'package:qless/presentation/patient/screens/appintment_screen.dart';
import 'package:qless/presentation/patient/screens/patient_notification.dart';
import 'package:qless/presentation/patient/screens/patient_prescription_list.dart';
import 'package:qless/presentation/shared/controllers/sync_controller.dart';
import 'package:qless/presentation/shared/screens/continue_as.dart';
import 'package:qless/presentation/shared/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>(); //Global navigator access
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(); //Global scaffold messenger access

// Step 1 — Background / terminated message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

// Step 2 — Notification tap router
void _handleNotificationTap(Map<String, dynamic> data) {
  final type = data['type']?.toString();
  final id   = data['id']?.toString();
  final nav  = navigatorKey.currentState;
  if (nav == null) return;
  switch (type) {
    case 'appointment':
      nav.pushNamed('/appointment', arguments: id);
      break;
    case 'queue':
      nav.pushNamed('/queue', arguments: id);
      break;
    case 'prescription':
      nav.pushNamed('/prescription', arguments: id);
      break;
    default:
      nav.pushNamed('/notifications');
  }
}

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

  // Step 1 — register background handler before any other FCM setup
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  await _setupNotifications();

  final container = ProviderContainer();
  await container.read(tokenProvider.notifier).loadTokens();
  // Grab the notifier so foreground FCM messages can be appended to it
  _notificationNotifier = container.read(notificationProvider.notifier);
  runApp(
    UncontrolledProviderScope(
      container: container,
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
      routes: {
        '/notifications': (_) => const NotificationsScreen(),
        '/appointment':   (_) => const AppointmentScreen(),
        '/prescription':  (_) => const PatientPrescriptionListScreen(),
      },
      home: QlessSplashScreen(
        nextScreen: const ContinueAsScreen(), // your existing role-select screen
      ), // ✅ Auto-login logic
    );
  }
}

// Global reference to the notification notifier set after ProviderScope mounts
NotificationNotifier? _notificationNotifier;

Future<void> _setupNotifications() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

  // Step 2a — local notification tap handler (foreground)
  await _localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      _handleNotificationTap(
        jsonDecode(details.payload ?? '{}') as Map<String, dynamic>,
      );
    },
  );

  final androidPlugin = _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_androidChannel);

  if (defaultTargetPlatform == TargetPlatform.android) {
    final status = await Permission.notification.request();
    debugPrint('Notification permission status: $status');
  }

  // Step 2b — app was terminated, user tapped the notification to open it
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleNotificationTap(initialMessage.data);
  }

  // Step 2c — app was in background, user tapped the notification
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    _handleNotificationTap(message.data);
  });

  // Step 4 — token refresh: re-save to backend when FCM rotates the token
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    debugPrint('FCM token refreshed: $newToken');
    // TODO: call your saveFirebaseToken API with newToken if user is logged in
  });

  // Foreground messages — show banner + add to in-app list
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    final data         = message.data;
    final title = notification?.title ?? data['title']?.toString();
    final body  = notification?.body  ?? data['body']?.toString();

    if (title == null && body == null) return;

    // Step 3 — pass data as payload so tap handler can route correctly
    _localNotifications.show(
      notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title ?? 'Notification',
      body  ?? '',
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
      payload: jsonEncode(data),
    );

    // Step 5 — add to in-app notification list
    _notificationNotifier?.add(NotificationItem(
      title:      title ?? 'Notification',
      body:       body  ?? '',
      type:       data['type']?.toString() ?? 'general',
      refId:      data['id']?.toString(),
      receivedAt: DateTime.now(),
    ));
  });
}
