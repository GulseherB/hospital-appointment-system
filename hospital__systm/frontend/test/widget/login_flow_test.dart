import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_app/main.dart';
import 'package:hospital_app/services/api_client.dart';
import 'package:hospital_app/services/auth_service.dart';
import 'package:hospital_app/services/token_storage.dart';
import 'package:hospital_app/state/session_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Future<SessionController> _pumpApp(WidgetTester tester, Map<String, dynamic> loginResponse) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = ApiClient(
    baseUrl: 'http://test/api/v1',
    httpClient: MockClient((req) async => _json(loginResponse, 200)),
  );
  final session = SessionController(authService: AuthService(api), storage: MemoryTokenStorage());
  api.tokenProvider = () => session.token;
  await session.restore();
  await tester.pumpWidget(HospitalApp(api: api, session: session));
  await tester.pumpAndSettle();
  return session;
}

Future<void> _login(WidgetTester tester, String option, String email) async {
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'E-posta'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Şifre'), 'Demo_Example_123');
  await tester.tap(find.text('Giriş Yap'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('açılış ekranında beş seçenek vardır', (tester) async {
    await _pumpApp(tester, {});
    for (final label in ['Hasta Girişi', 'Hasta Kaydı', 'Doktor Girişi', 'Yönetici Girişi', 'Kurum Başvurusu']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('hasta girişi hasta menüsünü açar', (tester) async {
    await _pumpApp(tester, {
      'token': 't',
      'must_change_password': false,
      'user': {'id': 5, 'role': 'patient', 'first_name': 'Ali', 'last_name': 'Örnek', 'email': 'patient@demo.local'},
    });
    await _login(tester, 'Hasta Girişi', 'patient@demo.local');

    expect(find.text('Randevularım'), findsOneWidget);
    expect(find.text('Bildirimler'), findsOneWidget);
    expect(find.textContaining('Ali Örnek · Hasta'), findsOneWidget);
  });

  testWidgets('geçici şifreli doktor zorunlu şifre ekranına düşer', (tester) async {
    await _pumpApp(tester, {
      'token': 't',
      'must_change_password': true,
      'user': {'id': 4, 'role': 'doctor', 'first_name': 'Mehmet', 'last_name': 'Kaya', 'email': 'doctor2@demo.local'},
    });
    await _login(tester, 'Doktor Girişi', 'doctor2@demo.local');

    expect(find.text('Şifre Değiştir'), findsWidgets);
    expect(find.textContaining('Geçici bir şifreyle giriş yaptınız'), findsOneWidget);
    expect(find.text('Bekleyen Randevular'), findsNothing);
  });

  testWidgets('hasta hesabı doktor girişinden giremez', (tester) async {
    final session = await _pumpApp(tester, {
      'token': 't',
      'must_change_password': false,
      'user': {'id': 5, 'role': 'patient', 'first_name': 'Ali', 'last_name': 'Örnek', 'email': 'patient@demo.local'},
    });
    await _login(tester, 'Doktor Girişi', 'patient@demo.local');

    expect(find.textContaining('Bu hesap bir Hasta hesabı'), findsOneWidget);
    expect(session.isLoggedIn, isFalse);
  });
}
