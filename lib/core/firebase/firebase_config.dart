import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static const FirebaseOptions demoOptions = FirebaseOptions(
    apiKey: 'AIzaSyDemo-MeqyasFakeApiKeyForEmulator123',
    appId: '1:100000000000:web:meqyas-demo-app-id',
    messagingSenderId: '100000000000',
    projectId: 'demo-meqyas',
    storageBucket: 'demo-meqyas.appspot.com',
  );

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: demoOptions,
    );

    // In debug/demo mode, connect to the local emulator suite
    if (kDebugMode) {
      await connectToEmulators();
    }
  }

  static Future<void> connectToEmulators() async {
    final host = (!kIsWeb && Platform.isAndroid) ? '10.0.2.2' : 'localhost';

    try {
      FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8085);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      FirebaseStorage.instance.useStorageEmulator(host, 9199);

      // Enable Firestore offline persistence
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firebase Emulator connection notice: $e');
    }
  }
}
