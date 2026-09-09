// Basic smoke test untuk aplikasi NurisGo.
//
// Memastikan layar selamat datang (welcome) dari LoginScreen bisa
// dirender tanpa crash. Firebase di-mock via setupFirebaseCoreMocks
// karena LoginScreen membuat AuthService (butuh Firebase terinisialisasi).

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_3/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupFirebaseCoreMocks();
  });

  setUp(() async {
    await Firebase.initializeApp();
  });

  testWidgets('Welcome screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AbsensiSantriApp());
    await tester.pump();

    expect(find.text('ABSENSI'), findsOneWidget);
    expect(find.text("LET'S GO"), findsOneWidget);
  });

  testWidgets('Can navigate to login form', (WidgetTester tester) async {
    await tester.pumpWidget(const AbsensiSantriApp());
    await tester.pump();

    await tester.tap(find.text("LET'S GO"));
    await tester.pumpAndSettle();

    expect(find.text('SELAMAT DATANG'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}