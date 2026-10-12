import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradeflow/main.dart';

void main() {
  testWidgets('Login and registration render on narrow and wide screens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(const GradeFlow());
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('GradeFlow'), findsOneWidget);
    await tester.tap(find.text('New student? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
