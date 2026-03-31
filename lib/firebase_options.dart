import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase options for this project.
///
/// NOTE: This file was generated manually from android/app/google-services.json.
/// If you add iOS/web support later, update this file accordingly.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for Fuchsia.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAu9URRhAdofq_GuVrJsfNmYixj0fKcQVI',
    appId: '1:644313122183:android:383980469e9142aa3cff22',
    messagingSenderId: '644313122183',
    projectId: 'qless-4f033',
    storageBucket: 'qless-4f033.firebasestorage.app',
  );
}
