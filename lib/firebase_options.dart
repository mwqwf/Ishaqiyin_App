import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for the Ishaqiyin app.
///
/// Values mirror the original project's `google-services.json`
/// (Firebase project: mxqp-8d1e8). The Android client package that
/// matches `appId` below is `com.ali.menbarishaqeen`.
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
        // iOS is not registered yet; reuse the project for read-only access.
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCWAHqbzhfQ-ZcjSSVCAhFFqCTgQ66SdCs',
    appId: '1:502388954405:android:6ca4f526675c8c3a89b6cc',
    messagingSenderId: '502388954405',
    projectId: 'mxqp-8d1e8',
    storageBucket: 'mxqp-8d1e8.firebasestorage.app',
  );
}
