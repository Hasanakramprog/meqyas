import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/user_role.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSubscription;
  final _authStateController = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance {
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      _authSubscription = _auth.authStateChanges().listen((firebaseUser) async {
        try {
          _userDocSubscription?.cancel();

          if (firebaseUser == null) {
            _currentUser = null;
            _authStateController.add(null);
            return;
          }

          String? roleStr;
          String? workshopId;
          String? supplierId;

          try {
            final tokenResult = await firebaseUser.getIdTokenResult(true);
            roleStr = tokenResult.claims?['role'] as String?;
            workshopId = tokenResult.claims?['workshopId'] as String?;
            supplierId = tokenResult.claims?['supplierId'] as String?;
          } catch (e) {
            debugPrint('Failed to refresh ID token claims: $e');
          }

          // Initial fallback user before Firestore doc arrives
          _currentUser = AppUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            fullName: firebaseUser.displayName ?? '',
            phone: '',
            isEmailVerified: firebaseUser.emailVerified,
            role: UserRole.fromCode(roleStr),
            workshopId: workshopId,
            supplierId: supplierId,
          );
          _authStateController.add(_currentUser);

          // Listen to users/{uid} document in Firestore
          _userDocSubscription = _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .snapshots()
              .listen(
            (doc) {
              if (doc.exists && doc.data() != null) {
                final data = doc.data()!;
                _currentUser = AppUser.fromMap(
                  data,
                  firebaseUser.uid,
                  isEmailVerified: firebaseUser.emailVerified,
                );
              }
              _authStateController.add(_currentUser);
            },
            onError: (error) {
              debugPrint('Firestore user doc listen error: $error');
            },
          );
        } catch (e) {
          debugPrint('Auth listener processing error: $e');
        }
      });
    } catch (e) {
      debugPrint('Auth listener initialization error: $e');
    }
  }

  @override
  Stream<AppUser?> authState() => _authStateController.stream;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<void> signUp(SignUpData data) async {
    // 1. Create auth user with email & password
    final cred = await _auth.createUserWithEmailAndPassword(
      email: data.email.trim(),
      password: data.password,
    );

    final user = cred.user;
    if (user == null) {
      throw Exception('فشل إنشاء المستخدم في نظام المصادقة');
    }

    await user.updateDisplayName(data.fullName.trim());

    // 2. Send email verification
    try {
      await user.sendEmailVerification();
    } catch (_) {
      // In local emulator, continue even if mailer service mock throws
    }

    // 3. Call bootstrapOwner Cloud Function (creates workshop, user doc, sets claims)
    final callable = _functions.httpsCallable('bootstrapOwner');
    await callable.call({
      'fullName': data.fullName.trim(),
      'phone': data.phone.trim(),
      'workshopName': data.workshopName.trim(),
      'workshopLocation': data.workshopLocation.trim(),
    });

    // 4. Force token refresh to capture the newly set custom claims
    await user.getIdToken(true);
  }

  @override
  Future<void> signIn(SignInData data) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: data.email.trim(),
      password: data.password,
    );

    await cred.user?.getIdToken(true);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  @override
  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.reload();
        await user.getIdToken(true);
      } catch (e) {
        debugPrint('reloadUser failed (user likely deleted or session expired): $e');
        if (e.toString().contains('user-token-expired') ||
            e.toString().contains('user-not-found')) {
          await signOut();
          return;
        }
      }
      final refreshed = _auth.currentUser;
      if (refreshed != null) {
        if (_currentUser != null) {
          _currentUser = AppUser(
            uid: _currentUser!.uid,
            email: _currentUser!.email,
            fullName: _currentUser!.fullName,
            phone: _currentUser!.phone,
            phoneVerifiedAt: _currentUser!.phoneVerifiedAt,
            isEmailVerified: refreshed.emailVerified,
            role: _currentUser!.role,
            status: _currentUser!.status,
            workshopId: _currentUser!.workshopId,
            supplierId: _currentUser!.supplierId,
          );
        } else {
          _currentUser = AppUser(
            uid: refreshed.uid,
            email: refreshed.email ?? '',
            fullName: refreshed.displayName ?? '',
            phone: '',
            isEmailVerified: refreshed.emailVerified,
            role: UserRole.owner,
          );
        }
        _authStateController.add(_currentUser);
      }
    }
  }

  @override
  Future<void> verifyPhone(String code) async {
    // Deferred to Phase 7 as specified in the spec
    throw UnsupportedError('Phone verification is deferred to Phase 7');
  }

  @override
  Future<void> signOut() async {
    _userDocSubscription?.cancel();
    await _auth.signOut();
  }

  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    _authStateController.close();
  }
}
