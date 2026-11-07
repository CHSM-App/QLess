import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Returns the FCM token. On iOS, `getToken()` returns null until the APNs
/// token has been registered, so wait for it briefly first. Android is
/// unaffected and goes straight to `getToken()`.
Future<String?> getFcmTokenSafe() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    String? apns;
    for (var i = 0; i < 10 && apns == null; i++) {
      apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns == null) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }
  return FirebaseMessaging.instance.getToken();
}
