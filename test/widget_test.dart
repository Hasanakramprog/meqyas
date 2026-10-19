import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meqyas/features/auth/domain/app_user.dart';
import 'package:meqyas/features/auth/domain/auth_repository.dart';
import 'package:meqyas/features/auth/presentation/controllers/auth_controller.dart';
import 'package:meqyas/main.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Stream<AppUser?> authState() => Stream.value(null);

  @override
  AppUser? get currentUser => null;

  @override
  Future<void> reloadUser() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signIn(SignInData data) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp(SignUpData data) async {}

  @override
  Future<void> verifyPhone(String code) async {}
}

void main() {
  testWidgets('MeqyasApp loads in Arabic RTL with header title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const MeqyasApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مِقْيَاس'), findsWidgets);
    expect(find.text('هندسة الألمنيوم والزجاج'), findsOneWidget);
  });
}
