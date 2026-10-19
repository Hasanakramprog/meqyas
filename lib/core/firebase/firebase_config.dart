import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static FirebaseOptions get currentPlatformOptions {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyDemo-MeqyasFakeApiKeyForEmulator123',
        appId: '1:100000000000:web:meqyas-demo-app-id',
        messagingSenderId: '100000000000',
        projectId: 'demo-meqyas',
        storageBucket: 'demo-meqyas.appspot.com',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyDemo-MeqyasFakeApiKeyForEmulator123',
        appId: '1:100000000000:ios:a1b2c3d4e5f60718',
        messagingSenderId: '100000000000',
        projectId: 'demo-meqyas',
        storageBucket: 'demo-meqyas.appspot.com',
        iosBundleId: 'com.meqyas.meqyas',
      );
    }
    return const FirebaseOptions(
      apiKey: 'AIzaSyDemo-MeqyasFakeApiKeyForEmulator123',
      appId: '1:100000000000:android:meqyas-demo-app-id',
      messagingSenderId: '100000000000',
      projectId: 'demo-meqyas',
      storageBucket: 'demo-meqyas.appspot.com',
    );
  }

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: currentPlatformOptions,
        );
      }

      if (kDebugMode) {
        await connectToEmulators();
      }
    } catch (e, stack) {
      debugPrint('Firebase initialization notice: $e\n$stack');
    }
  }

  static Future<void> connectToEmulators() async {
    final host = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? '10.0.2.2'
        : '127.0.0.1';

    try {
      FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8085);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      FirebaseStorage.instance.useStorageEmulator(host, 9199);
    } catch (e) {
      debugPrint('Firebase Emulator connection notice: $e');
    }
  }
}
