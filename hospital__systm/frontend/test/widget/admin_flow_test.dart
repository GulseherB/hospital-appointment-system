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

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _app(String status) => {
  'id': 3,
  'status': status,
  'institution': {
    'name': 'Test Hastanesi',
    'type': 'hospital',
    'address': 'Test Cad. 5',
    'phone': '02161112233',
    'email': 'info@test.local',
  },
  'admin': {'first_name': 'Ece', 'last_name': 'Kurt', 'email': 'ece@test.local', 'phone': '05321112233'},
  'institution_id': status == 'approved' ? 2 : null,
  'created_at': '2026-11-13T11:54:19',
  'decided_at': status == 'approved' ? '2026-11-13T11:54:20' : null,
};

Future<List<String>> _pump(
  WidgetTester tester,
  Map<String, dynamic> user,
  http.Response Function(http.Request) route,
) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = <String>[];
  final api = ApiClient(
    baseUrl: 'http://test/api/v1',
    httpClient: MockClient((req) async {
      calls.add('${req.method} ${req.url.path.replaceFirst('/api/v1', '')}');
      if (req.url.path.endsWith('/auth/me')) return _json({'must_change_password': false, 'user': user});
      return route(req);
    }),
  );
  final storage = MemoryTokenStorage();
  await storage.write('tok');
  final session = SessionController(authService: AuthService(api), storage: storage);
  api.tokenProvider = () => session.token;
  await session.restore();
  await tester.pumpWidget(HospitalApp(api: api, session: session));
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('süper admin bekleyen başvuruyu onaylar', (tester) async {
    var approved = false;
    final calls = await _pump(
      tester,
      {'id': 1, 'role': 'super_admin', 'first_name': 'Süper', 'last_name': 'Admin', 'email': 's@h.local'},
      (req) {
        if (req.url.path.endsWith('/approve')) {
          approved = true;
          return _json(_app('approved'));
        }
        return _json({
          'items': [if (!approved) _app('pending')],
        });
      },
    );

    expect(find.text('Test Hastanesi'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Onayla'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"Merkez" şubesi açılacak'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Onayla').last);
    await tester.pumpAndSettle();

    expect(calls, contains('POST /admin/applications/3/approve'));
    expect(calls.where((c) => c.startsWith('GET /admin/applications')).length, 2, reason: 'liste yenilenmeli');
    expect(find.text('Bu durumda başvuru yok.'), findsOneWidget);
  });

  testWidgets('yönetici doktor ekler ve geçici şifreyi görür', (tester) async {
    Map<String, dynamic>? sent;
    await _pump(
      tester,
      {
        'id': 7,
        'role': 'institution_admin',
        'first_name': 'Ece',
        'last_name': 'Kurt',
        'email': 'ece@test.local',
        'institution_id': 2,
      },
      (req) {
        final path = req.url.path;
        if (path.endsWith('/manage/branches')) {
          return _json({
            'items': [
              {'id': 2, 'institution_id': 2, 'name': 'Merkez', 'address': '', 'phone': '', 'is_active': true},
            ],
          });
        }
        if (path.endsWith('/manage/departments')) {
          return _json({
            'items': [
              {'id': 3, 'branch_id': 2, 'name': 'Kardiyoloji', 'is_active': true},
            ],
          });
        }
        if (path.endsWith('/manage/doctors') && req.method == 'POST') {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({
            'id': 8,
            'first_name': 'Can',
            'last_name': 'Ak',
            'email': 'can@test.local',
            'phone': '05330000000',
            'branch_id': 2,
            'department_id': 3,
            'specialty': '',
            'is_active': true,
            'service_ids': [],
            'temporary_password': 'TEMP12345abc',
          }, 201);
        }
        return _json({'items': []});
      },
    );

    await tester.tap(find.text('Doktorlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doktor Ekle'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Ad'), 'Can');
    await tester.enterText(find.widgetWithText(TextFormField, 'Soyad'), 'Ak');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-posta (giriş için)'), 'can@test.local');
    await tester.enterText(find.widgetWithText(TextFormField, 'Telefon'), '05330000000');
    await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
    await tester.pumpAndSettle();

    expect(sent, isNotNull);
    expect(sent!['branch_id'], 2);
    expect(sent!['department_id'], 3);
    expect(find.text('TEMP12345abc'), findsOneWidget);
    expect(find.textContaining('yalnızca şimdi gösterilir'), findsOneWidget);
  });

  testWidgets('yönetici doktoru pasifleştirmek ister; ileri tarihli randevu hatası pencerede gösterilir', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    await _pump(
      tester,
      {
        'id': 7,
        'role': 'institution_admin',
        'first_name': 'Ece',
        'last_name': 'Kurt',
        'email': 'ece@test.local',
        'institution_id': 2,
      },
      (req) {
        final path = req.url.path;
        if (path.endsWith('/manage/branches')) {
          return _json({
            'items': [
              {'id': 2, 'institution_id': 2, 'name': 'Merkez', 'address': '', 'phone': '', 'is_active': true},
            ],
          });
        }
        if (path.endsWith('/manage/departments')) {
          return _json({
            'items': [
              {'id': 3, 'branch_id': 2, 'name': 'Kardiyoloji', 'is_active': true},
            ],
          });
        }
        if (path.endsWith('/manage/doctors/8') && req.method == 'PUT') {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({
            'error': {
              'code': 'HAS_FUTURE_APPOINTMENTS',
              'message':
                  'Doktor için ileri tarihli 2 aktif randevu var. Önce bu randevular iptal edilmeli veya tamamlanmalıdır.',
            },
          }, 409);
        }
        if (path.endsWith('/manage/doctors')) {
          return _json({
            'items': [
              {
                'id': 8,
                'first_name': 'Can',
                'last_name': 'Ak',
                'email': 'can@test.local',
                'phone': '05330000000',
                'branch_id': 2,
                'department_id': 3,
                'specialty': 'Kardiyoloji',
                'is_active': true,
                'service_ids': [5],
              },
            ],
          });
        }
        return _json({'items': []});
      },
    );

    await tester.tap(find.text('Doktorlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Düzenle'));
    await tester.pumpAndSettle();
    expect(find.text('Doktoru Düzenle'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'E-posta (giriş için)'), findsNothing, reason: 'e-posta değiştirilemez');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    expect(sent, {
      'first_name': 'Can',
      'last_name': 'Ak',
      'phone': '05330000000',
      'specialty': 'Kardiyoloji',
      'branch_id': 2,
      'department_id': 3,
      'is_active': false,
    });
    expect(find.textContaining('ileri tarihli 2 aktif randevu'), findsOneWidget);
    expect(find.text('Doktoru Düzenle'), findsOneWidget, reason: 'hata durumunda pencere açık kalır');
  });

  testWidgets('süper admin kurumu pasifleştirir ve yönetici şifresini sıfırlar', (tester) async {
    var active = true;
    final calls = await _pump(
      tester,
      {'id': 1, 'role': 'super_admin', 'first_name': 'Süper', 'last_name': 'Admin', 'email': 's@h.local'},
      (req) {
        final path = req.url.path;
        if (path.endsWith('/reset-admin-password')) {
          return _json({
            'institution_id': 2,
            'admin_first_name': 'Ece',
            'admin_last_name': 'Kurt',
            'admin_email': 'ece@test.local',
            'temporary_password': 'NEWtemp12345',
          });
        }
        Map<String, dynamic> inst() => {
          'id': 2,
          'name': 'Test Hastanesi',
          'type': 'hospital',
          'address': 'Test Cad. 5',
          'phone': '02161112233',
          'email': 'info@test.local',
          'is_active': active,
        };
        if (req.method == 'PATCH') {
          active = (jsonDecode(req.body) as Map)['is_active'] as bool;
          return _json(inst());
        }
        if (path.endsWith('/admin/institutions')) {
          return _json({
            'items': [inst()],
          });
        }
        return _json({'items': []});
      },
    );

    await tester.tap(find.text('Kurumlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Pasifleştir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Pasifleştir'));
    await tester.pumpAndSettle();
    expect(calls, contains('PATCH /admin/institutions/2'));
    expect(find.widgetWithText(OutlinedButton, 'Aktifleştir'), findsOneWidget, reason: 'liste yenilenir');

    await tester.tap(find.text('Yönetici Şifresini Sıfırla'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sıfırla'));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /admin/institutions/2/reset-admin-password'));
    expect(find.text('NEWtemp12345'), findsOneWidget);
    expect(find.textContaining('Kurum yöneticisine iletin'), findsOneWidget);
  });
}
