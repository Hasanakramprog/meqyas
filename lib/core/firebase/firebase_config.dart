import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:meqyas/firebase_options.dart';

class FirebaseConfig {
  /// Set via `--dart-define=USE_FIREBASE_EMULATOR=true` only if you explicitly
  /// want to use the local emulator. Defaults to `false` (real Cloud Firebase).
  static const bool useEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  static FirebaseOptions get currentPlatformOptions =>
      DefaultFirebaseOptions.currentPlatform;

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: currentPlatformOptions,
        );
      }

      if (useEmulator) {
        await connectToEmulators();
      }

      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
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
