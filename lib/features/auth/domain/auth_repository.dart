import 'app_user.dart';

class SignUpData {
  final String fullName;
  final String email;
  final String password;
  final String phone;
  final String workshopName;
  final String workshopLocation;

  const SignUpData({
    required this.fullName,
    required this.email,
    required this.password,
    required this.phone,
    required this.workshopName,
    required this.workshopLocation,
  });
}

class SignInData {
  final String email;
  final String password;

  const SignInData({
    required this.email,
    required this.password,
  });
}

abstract class AuthRepository {
  Stream<AppUser?> authState();
  AppUser? get currentUser;
  Future<void> signUp(SignUpData data);
  Future<void> signIn(SignInData data);
  Future<void> sendPasswordReset(String email);
  Future<void> sendEmailVerification();
  Future<void> reloadUser();
  Future<void> verifyPhone(String code);
  Future<void> signOut();
}
