import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/firebase/offline_firestore_helper.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/user_role.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Non-null when this device was automatically signed out because another device
  /// signed into the same account (`Single-Device Session Lock`).
  static String? lastSessionConflictMessage;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSubscription;
  final _authStateController = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;
  bool _hasEmittedInitial = false;
  String? _localSessionId;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance {
    _initAuthListener();
  }

  void _emitAuthState(AppUser? user) {
    _currentUser = user;
    _hasEmittedInitial = true;
    if (!_authStateController.isClosed) {
      _authStateController.add(user);
    }
  }

  void _initAuthListener() {
    try {
      _authSubscription = _auth.authStateChanges().listen((firebaseUser) async {
        try {
          _userDocSubscription?.cancel();

          if (firebaseUser == null) {
            _emitAuthState(null);
            return;
          }

          String? roleStr;
          String? workshopId;
          String? supplierId;

          try {
            // Read cached token claims first so persisted sessions restore immediately
            final tokenResult = await firebaseUser.getIdTokenResult(false);
            roleStr = tokenResult.claims?['role'] as String?;
            workshopId = tokenResult.claims?['workshopId'] as String?;
            supplierId = tokenResult.claims?['supplierId'] as String?;
          } catch (e) {
            debugPrint('Failed to read cached ID token claims: $e');
          }

          // 1) Read users/{uid} from local SQLite cache FIRST for instant (< 50ms)
          //    startup in Airplane Mode, then fall back to network if not cached yet.
          try {
            final userRef = _firestore.collection('users').doc(firebaseUser.uid);
            DocumentSnapshot<Map<String, dynamic>>? initialDoc;
            try {
              final cached = await userRef.get(const GetOptions(source: Source.cache));
              if (cached.exists && cached.data() != null) {
                initialDoc = cached;
              }
            } catch (_) {}

            initialDoc ??= await OfflineFirestoreHelper.getDocOfflineSafe(userRef);

            if (initialDoc.exists && initialDoc.data() != null) {
              final docData = initialDoc.data()!;
              _localSessionId ??= docData['activeSessionId'] as String?;
              _emitAuthState(
                AppUser.fromMap(
                  docData,
                  firebaseUser.uid,
                  isEmailVerified: firebaseUser.emailVerified,
                ),
              );
            } else if (OfflineFirestoreHelper.isOnline) {
              // Self-heal if a user registered when the batch failed or before users/{uid} was written
              final resolvedRole = UserRole.fromCode(roleStr);
              var resolvedWorkshopId = workshopId;
              if (resolvedRole == UserRole.owner &&
                  (resolvedWorkshopId == null || resolvedWorkshopId.isEmpty)) {
                final wRef = _firestore.collection('workshops').doc();
                resolvedWorkshopId = wRef.id;
                try {
                  await OfflineFirestoreHelper.writeOfflineSafe(
                    wRef.set({
                      'id': wRef.id,
                      'name': firebaseUser.displayName?.isNotEmpty == true
                          ? 'ورشة ${firebaseUser.displayName}'
                          : 'ورشة جديدة',
                      'ownerUid': firebaseUser.uid,
                      'phone': '',
                      'location': '',
                      'status': 'active',
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }),
                  );
                } catch (e) {
                  debugPrint('Self-heal workshop creation notice: $e');
                }
              }
              final newSessionId = _generateSessionId(firebaseUser.uid);
              _localSessionId = newSessionId;
              try {
                await OfflineFirestoreHelper.writeOfflineSafe(
                  _firestore.collection('users').doc(firebaseUser.uid).set({
                    'uid': firebaseUser.uid,
                    'email': firebaseUser.email ?? '',
                    'fullName': firebaseUser.displayName ?? '',
                    'phone': '',
                    'isEmailVerified': firebaseUser.emailVerified,
                    'role': resolvedRole.code,
                    'status': 'active',
                    'workshopId': resolvedWorkshopId,
                    'supplierId': supplierId,
                    'activeSessionId': newSessionId,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true)),
                );
              } catch (e) {
                debugPrint('Self-heal user doc creation notice: $e');
              }
              _emitAuthState(
                AppUser(
                  uid: firebaseUser.uid,
                  email: firebaseUser.email ?? '',
                  fullName: firebaseUser.displayName ?? '',
                  phone: '',
                  isEmailVerified: firebaseUser.emailVerified,
                  role: resolvedRole,
                  workshopId: resolvedWorkshopId,
                  supplierId: supplierId,
                ),
              );
            } else {
              _emitAuthState(
                AppUser(
                  uid: firebaseUser.uid,
                  email: firebaseUser.email ?? '',
                  fullName: firebaseUser.displayName ?? '',
                  phone: '',
                  isEmailVerified: firebaseUser.emailVerified,
                  role: UserRole.fromCode(roleStr),
                  workshopId: workshopId,
                  supplierId: supplierId,
                ),
              );
            }
          } catch (e) {
            debugPrint('Initial user doc fetch notice: $e');
            _emitAuthState(
              AppUser(
                uid: firebaseUser.uid,
                email: firebaseUser.email ?? '',
                fullName: firebaseUser.displayName ?? '',
                phone: '',
                isEmailVerified: firebaseUser.emailVerified,
                role: UserRole.fromCode(roleStr),
                workshopId: workshopId,
                supplierId: supplierId,
              ),
            );
          }

          // Listen to users/{uid} document in Firestore (with metadata for Single-Device Session Lock)
          _userDocSubscription = _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .snapshots(includeMetadataChanges: true)
              .listen(
            (doc) {
              if (doc.exists && doc.data() != null) {
                final data = doc.data()!;
                final remoteSessionId = data['activeSessionId'] as String?;

                // Single-Device Session Lock:
                // Only enforce when receiving a confirmed live server snapshot (not cache, no pending local writes)
                if (!doc.metadata.isFromCache &&
                    !doc.metadata.hasPendingWrites &&
                    remoteSessionId != null &&
                    remoteSessionId.isNotEmpty) {
                  if (_localSessionId == null) {
                    _localSessionId = remoteSessionId;
                  } else if (_localSessionId != remoteSessionId) {
                    lastSessionConflictMessage =
                        'تم تسجيل الدخول إلى هذا الحساب من جهاز آخر. يُسمح بجهاز نشط واحد فقط لمنع تضارب البيانات.';
                    unawaited(signOut());
                    return;
                  }
                } else if (_localSessionId == null &&
                    remoteSessionId != null &&
                    remoteSessionId.isNotEmpty) {
                  _localSessionId = remoteSessionId;
                }

                _currentUser = AppUser.fromMap(
                  data,
                  firebaseUser.uid,
                  isEmailVerified: firebaseUser.emailVerified,
                );
              }
              _emitAuthState(_currentUser);
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
  Stream<AppUser?> authState() {
    return Stream<AppUser?>.multi((controller) {
      if (_hasEmittedInitial) {
        controller.add(_currentUser);
      }
      final sub = _authStateController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  AppUser? get currentUser => _currentUser;

  String _generateSessionId(String uid) {
    final shortUid = uid.length >= 6 ? uid.substring(0, 6) : uid;
    return 'sess_${DateTime.now().millisecondsSinceEpoch}_$shortUid';
  }

  @override
  Future<void> signUp(SignUpData data) async {
    final online = await OfflineFirestoreHelper.checkConnectivityNow();
    if (!online) {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'لا يوجد اتصال بالإنترنت حالياً. إنشاء حساب جديد يتطلب اتصالاً بالإنترنت.',
      );
    }

    lastSessionConflictMessage = null;

    // 1. Create auth user with email & password
    final cred = await _auth.createUserWithEmailAndPassword(
      email: data.email.trim(),
      password: data.password,
    );

    final user = cred.user;
    if (user == null) {
      throw Exception('فشل إنشاء المستخدم في نظام المصادقة');
    }

    final sessionId = _generateSessionId(user.uid);
    _localSessionId = sessionId;

    await user.updateDisplayName(data.fullName.trim());

    // 2. Send email verification
    try {
      await user.sendEmailVerification();
    } catch (_) {
      // In local emulator, continue even if mailer service mock throws
    }

    // 3. Call bootstrapOwner Cloud Function (or fall back to direct Firestore bootstrap on Spark plan)
    try {
      final callable = _functions.httpsCallable('bootstrapOwner');
      await callable.call({
        'fullName': data.fullName.trim(),
        'phone': data.phone.trim(),
        'workshopName': data.workshopName.trim(),
        'workshopLocation': data.workshopLocation.trim(),
      });
      await OfflineFirestoreHelper.writeOfflineSafe(
        _firestore.collection('users').doc(user.uid).set({
          'activeSessionId': sessionId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      );
    } catch (e) {
      debugPrint('bootstrapOwner Cloud Function unavailable, using direct Firestore bootstrap: $e');
      final workshopRef = _firestore.collection('workshops').doc();
      // 1) Write users/{uid} FIRST so security rules know the user's role & workshopId
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': data.email.trim(),
        'fullName': data.fullName.trim(),
        'phone': data.phone.trim(),
        'isEmailVerified': user.emailVerified,
        'role': 'owner',
        'status': 'active',
        'workshopId': workshopRef.id,
        'supplierId': null,
        'activeSessionId': sessionId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // 2) Write workshops/{workshopId}
      await workshopRef.set({
        'id': workshopRef.id,
        'name': data.workshopName.trim(),
        'ownerUid': user.uid,
        'phone': data.phone.trim(),
        'location': data.workshopLocation.trim(),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 4. Force token refresh to capture any custom claims
    await user.getIdToken(true);
  }

  @override
  Future<void> signIn(SignInData data) async {
    final online = await OfflineFirestoreHelper.checkConnectivityNow();
    if (!online) {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'لا يوجد اتصال بالإنترنت حالياً. تسجيل الدخول يتطلب اتصالاً بالإنترنت.',
      );
    }

    lastSessionConflictMessage = null;

    final cred = await _auth.signInWithEmailAndPassword(
      email: data.email.trim(),
      password: data.password,
    );

    final user = cred.user;
    if (user != null) {
      final sessionId = _generateSessionId(user.uid);
      _localSessionId = sessionId;
      try {
        await OfflineFirestoreHelper.writeOfflineSafe(
          _firestore.collection('users').doc(user.uid).set({
            'activeSessionId': sessionId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        );
      } catch (e) {
        debugPrint('Failed to write activeSessionId on signIn: $e');
      }
      await user.getIdToken(true);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final online = await OfflineFirestoreHelper.checkConnectivityNow();
    if (!online) {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'لا يوجد اتصال بالإنترنت حالياً. استعادة كلمة المرور تتطلب اتصالاً بالإنترنت.',
      );
    }
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
    _localSessionId = null;
    await _auth.signOut();
  }

  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    _authStateController.close();
  }
}
