import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/firebase_auth_repository.dart';
import '../../domain/app_user.dart';
import '../../domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = FirebaseAuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authState();
});

class AuthActionState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const AuthActionState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  AuthActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return AuthActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class AuthActionNotifier extends Notifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthActionState();

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signIn(SignInData(email: email, password: password));
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _translateError(e),
        isSuccess: false,
      );
      return false;
    }
  }

  Future<bool> signUp(SignUpData data) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signUp(data);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _translateError(e),
        isSuccess: false,
      );
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.sendPasswordReset(email);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _translateError(e),
        isSuccess: false,
      );
      return false;
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.sendEmailVerification();
    } catch (e) {
      state = state.copyWith(errorMessage: _translateError(e));
    }
  }

  Future<void> reloadUser() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.reloadUser();
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
  }

  String _translateError(Object error) {
    final str = error.toString().toLowerCase();
    if (str.contains('user-not-found') || str.contains('wrong-password') || str.contains('invalid-credential')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (str.contains('email-already-in-use')) {
      return 'البريد الإلكتروني مسجل مسبقاً، يرجى تسجيل الدخول';
    }
    if (str.contains('invalid-email')) {
      return 'صيغة البريد الإلكتروني غير صالحة';
    }
    if (str.contains('weak-password')) {
      return 'كلمة المرور ضعيفة جداً، يرجى اختيار كلمة مرور أقوى';
    }
    if (str.contains('network-request-failed')) {
      return 'تعذر الاتصال بالخادم، تحقق من اتصال الإنترنت أو تشغيل المحاكي';
    }
    return 'حدث خطأ: ${error.toString()}';
  }
}

final authActionControllerProvider =
    NotifierProvider<AuthActionNotifier, AuthActionState>(AuthActionNotifier.new);
