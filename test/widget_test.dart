import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meqyas/main.dart';

void main() {
  testWidgets('MeqyasApp loads in Arabic RTL with header title',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MeqyasApp()));
    await tester.pumpAndSettle();

    expect(find.text('مِقْيَاس'), findsWidgets);
    expect(find.text('هندسة الألمنيوم والزجاج'), findsOneWidget);
  });
}
