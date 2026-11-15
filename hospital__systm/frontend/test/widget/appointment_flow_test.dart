import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_app/core/date_utils.dart';
import 'package:hospital_app/main.dart';
import 'package:hospital_app/models/institution.dart';
import 'package:hospital_app/services/api_client.dart';
import 'package:hospital_app/services/auth_service.dart';
import 'package:hospital_app/services/token_storage.dart';
import 'package:hospital_app/state/session_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// Testler gerçek saate göre göreli tarihler kullanır (arayüz kuralları cihaz saatiyle çalışır).
DateTime _daysAhead(int days, int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour, minute);
}

Map<String, dynamic> _appointment(int id, String status, DateTime start) => {
  'id': id,
  'status': status,
  'start_at': ApiDate.formatDateTime(start),
  'end_at': ApiDate.formatDateTime(start.add(const Duration(minutes: 15))),
  'service_id': 1,
  'service_name': 'Genel Muayene',
  'duration_min': 15,
  'price': '750.00',
  'doctor_id': 3,
  'doctor_name': 'Ayşe Demir',
  'patient_id': 5,
  'patient_name': 'Ali Örnek',
  'branch_name': 'Merkez',
  'institution_name': 'Demo Sağlık Kliniği',
  'cancelled_by': null,
  'cancelled_at': null,
  'created_at': '2026-11-13T14:00:00',
};

const _patient = {'id': 5, 'role': 'patient', 'first_name': 'Ali', 'last_name': 'Örnek', 'email': 'p@demo.local'};
const _doctor = {'id': 3, 'role': 'doctor', 'first_name': 'Ayşe', 'last_name': 'Demir', 'email': 'd@demo.local'};
const _admin = {
  'id': 2,
  'role': 'institution_admin',
  'first_name': 'Yön',
  'last_name': 'Etici',
  'email': 'a@demo.local',
  'institution_id': 1,
};

Future<List<http.Request>> _pump(
  WidgetTester tester,
  Map<String, dynamic> user,
  http.Response Function(http.Request) route,
) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final requests = <http.Request>[];
  final api = ApiClient(
    baseUrl: 'http://test/api/v1',
    httpClient: MockClient((req) async {
      requests.add(req);
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
  return requests;
}

String _path(http.Request r) => '${r.method} ${r.url.path.replaceFirst('/api/v1', '')}';

Future<void> _choose<T>(WidgetTester tester, String optionText) async {
  await tester.tap(find.byWidgetPredicate((w) => w is DropdownButtonFormField<T>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hasta: hizmet seçer, yalnızca kurala uyan slotları görür ve randevu alır', (tester) async {
    final day = _daysAhead(2, 0);
    Map<String, dynamic>? sentBody;
    final requests = await _pump(tester, _patient, (req) {
      final p = req.url.path;
      if (p.endsWith('/institutions')) {
        return _json({
          'items': [
            {
              'id': 1,
              'name': 'Demo Klinik',
              'type': 'clinic',
              'address': '',
              'phone': '',
              'email': '',
              'is_active': true,
            },
          ],
        });
      }
      if (p.endsWith('/institutions/1/branches')) {
        return _json({
          'items': [
            {'id': 1, 'institution_id': 1, 'name': 'Merkez', 'address': '', 'phone': '', 'is_active': true},
          ],
        });
      }
      if (p.endsWith('/branches/1/departments')) {
        return _json({
          'items': [
            {'id': 1, 'branch_id': 1, 'name': 'Dahiliye', 'is_active': true},
          ],
        });
      }
      if (p.endsWith('/services')) {
        return _json({
          'items': [
            {
              'id': 1,
              'department_id': 1,
              'name': 'Genel Muayene',
              'duration_min': 15,
              'price': '750.00',
              'is_active': true,
            },
          ],
        });
      }
      if (p.endsWith('/appointment-slots')) {
        Map<String, dynamic> slot(int h, int m) => {
          'doctor_id': 3,
          'doctor_name': 'Ayşe Demir',
          'start_at': ApiDate.formatDateTime(DateTime(day.year, day.month, day.day, h, m)),
          'end_at': ApiDate.formatDateTime(DateTime(day.year, day.month, day.day, h, m + 15)),
        };
        // 12:30 öğle arasındadır; sunucu göndermese de arayüz süzgeci göstermemeli.
        return _json({
          'items': [slot(10, 0), slot(12, 30)],
        });
      }
      if (p.endsWith('/appointments') && req.method == 'POST') {
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return _json(_appointment(9, 'pending', DateTime(day.year, day.month, day.day, 10)), 201);
      }
      if (p.endsWith('/my-notifications')) return _json({'items': [], 'unread_count': 2});
      return _json({'items': []});
    });

    expect(find.text('2'), findsOneWidget, reason: 'okunmamış bildirim rozeti');
    await _choose<Institution>(tester, 'Demo Klinik (Klinik)');
    await _choose<Branch>(tester, 'Merkez');
    await _choose<Department>(tester, 'Dahiliye');
    await _choose<Service>(tester, 'Genel Muayene · 15 dk · 750,00 ₺');

    expect(find.text('Dr. Ayşe Demir'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '10:00'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, '12:30'), findsNothing);

    await tester.tap(find.widgetWithText(ActionChip, '10:00'));
    await tester.pumpAndSettle();
    expect(find.textContaining('doktor onayına gönderilecek'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Randevu Al'));
    await tester.pumpAndSettle();

    expect(sentBody, {
      'service_id': 1,
      'doctor_id': 3,
      'start_at': ApiDate.formatDateTime(DateTime(day.year, day.month, day.day, 10)),
    });
    expect(requests.map(_path), contains('GET /my-appointments'), reason: 'randevu sonrası Randevularım açılır');
  });

  testWidgets('hasta: dolu slot hatası Türkçe gösterilir ve slotlar yenilenir', (tester) async {
    final day = _daysAhead(3, 0);
    var slotCalls = 0;
    await _pump(tester, _patient, (req) {
      final p = req.url.path;
      if (p.endsWith('/institutions')) {
        return _json({
          'items': [
            {'id': 1, 'name': 'K', 'type': 'hospital', 'address': '', 'phone': '', 'email': '', 'is_active': true},
          ],
        });
      }
      if (p.endsWith('/branches')) {
        return _json({
          'items': [
            {'id': 1, 'name': 'Ş', 'is_active': true},
          ],
        });
      }
      if (p.endsWith('/departments')) {
        return _json({
          'items': [
            {'id': 1, 'name': 'B', 'is_active': true},
          ],
        });
      }
      if (p.endsWith('/services')) {
        return _json({
          'items': [
            {'id': 1, 'name': 'H', 'duration_min': 15, 'price': '1.00'},
          ],
        });
      }
      if (p.endsWith('/appointment-slots')) {
        slotCalls++;
        return _json({
          'items': [
            {
              'doctor_id': 3,
              'doctor_name': 'Ayşe Demir',
              'start_at': ApiDate.formatDateTime(DateTime(day.year, day.month, day.day, 9)),
              'end_at': ApiDate.formatDateTime(DateTime(day.year, day.month, day.day, 9, 15)),
            },
          ],
        });
      }
      if (p.endsWith('/appointments') && req.method == 'POST') {
        return _json({
          'error': {'code': 'SLOT_TAKEN', 'message': 'Seçilen saat artık müsait değil.'},
        }, 409);
      }
      return _json({'items': [], 'unread_count': 0});
    });

    await _choose<Institution>(tester, 'K (Hastane)');
    await _choose<Branch>(tester, 'Ş');
    await _choose<Department>(tester, 'B');
    await _choose<Service>(tester, 'H · 15 dk · 1,00 ₺');
    await tester.tap(find.widgetWithText(ActionChip, '09:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Randevu Al'));
    await tester.pumpAndSettle();

    expect(find.text('Seçilen saat artık müsait değil.'), findsOneWidget);
    expect(slotCalls, 2, reason: 'hata sonrası slotlar yeniden yüklenmeli');
  });

  testWidgets('hasta: bildirime dokununca okundu işaretlenir, rozet güncellenir', (tester) async {
    var read = false;
    final requests = await _pump(tester, _patient, (req) {
      final p = req.url.path;
      if (p.endsWith('/my-notifications/7/read')) {
        read = true;
        return _json({
          'id': 7,
          'appointment_id': 9,
          'type': 'appointment_approved',
          'message': 'Dr. Ayşe Demir randevunuzu onayladı.',
          'is_read': true,
          'created_at': '2026-11-13T14:00:22',
        });
      }
      if (p.endsWith('/my-notifications')) {
        return _json({
          'items': [
            {
              'id': 7,
              'appointment_id': 9,
              'type': 'appointment_approved',
              'message': 'Dr. Ayşe Demir randevunuzu onayladı.',
              'is_read': read,
              'created_at': '2026-11-13T14:00:22',
            },
          ],
          'unread_count': read ? 0 : 1,
        });
      }
      return _json({'items': []});
    });

    await tester.tap(find.text('Bildirimler'));
    await tester.pumpAndSettle();
    expect(find.text('1 okunmamış bildirim'), findsOneWidget);
    await tester.tap(find.text('Dr. Ayşe Demir randevunuzu onayladı.'));
    await tester.pumpAndSettle();

    expect(requests.map(_path), contains('POST /my-notifications/7/read'));
    expect(find.text('Tüm bildirimler okundu.'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Badge && w.isLabelVisible),
      findsNothing,
      reason: 'okunmamış kalmayınca rozet gizlenir',
    );
  });

  testWidgets('hasta: 2 saatten az kalan randevuda iptal düğmesi yok', (tester) async {
    final soon = DateTime.now().add(const Duration(hours: 1));
    final later = _daysAhead(3, 10);
    final requests = await _pump(tester, _patient, (req) {
      if (req.url.path.endsWith('/appointments/2/cancel')) return _json(_appointment(2, 'cancelled', later));
      if (req.url.path.endsWith('/my-appointments')) {
        return _json({
          'items': [_appointment(1, 'approved', soon), _appointment(2, 'pending', later)],
        });
      }
      return _json({'items': [], 'unread_count': 0});
    });

    await tester.tap(find.text('Randevularım'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'İptal Et'), findsOneWidget);
    expect(find.text('Randevuya 2 saatten az kaldığı için iptal edilemez.'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'İptal Et'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'İptal Et'));
    await tester.pumpAndSettle();
    expect(requests.map(_path), contains('POST /appointments/2/cancel'));
  });

  testWidgets('doktor: bekleyen randevuyu onaylar; 12 saatten az kalanda onay düğmesi yok', (tester) async {
    final requests = await _pump(tester, _doctor, (req) {
      if (req.url.path.endsWith('/approve')) return _json(_appointment(1, 'approved', _daysAhead(2, 10)));
      return _json({
        'items': [
          _appointment(1, 'pending', _daysAhead(2, 10)),
          _appointment(2, 'pending', DateTime.now().add(const Duration(hours: 5))),
        ],
      });
    });

    expect(requests.firstWhere((r) => r.url.path.endsWith('/doctor/appointments')).url.query, 'status=pending');
    expect(find.widgetWithText(FilledButton, 'Onayla'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reddet'), findsNWidgets(2));
    expect(find.textContaining('Onay süresi doldu'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Onayla'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Onayla').last);
    await tester.pumpAndSettle();
    expect(requests.map(_path), contains('POST /doctor/appointments/1/approve'));
    expect(find.text('Randevu onaylandı.'), findsOneWidget);
  });

  testWidgets('yönetici: randevuları filtreler ve iptal eder', (tester) async {
    final requests = await _pump(tester, _admin, (req) {
      final p = req.url.path;
      if (p.endsWith('/manage/doctors')) {
        return _json({
          'items': [
            {
              'id': 3,
              'first_name': 'Ayşe',
              'last_name': 'Demir',
              'email': 'd@demo.local',
              'phone': '',
              'branch_id': 1,
              'department_id': 1,
              'specialty': '',
              'is_active': true,
              'service_ids': [1],
            },
          ],
        });
      }
      if (p.endsWith('/cancel')) return _json(_appointment(1, 'cancelled', _daysAhead(2, 10)));
      if (p.endsWith('/manage/appointments')) {
        return _json({
          'items': [_appointment(1, 'approved', _daysAhead(2, 10)), _appointment(2, 'completed', _daysAhead(-1, 10))],
        });
      }
      return _json({'items': []});
    });

    await tester.tap(find.text('Randevular'));
    await tester.pumpAndSettle();
    expect(find.text('Hasta: Ali Örnek'), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'İptal Et'), findsOneWidget, reason: 'tamamlanan iptal edilemez');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Onaylandı'));
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters, {'status': 'approved'});
    await _choose<int?>(tester, 'Dr. Ayşe Demir');
    expect(requests.last.url.queryParameters, {'status': 'approved', 'doctor_id': '3'});

    await tester.tap(find.widgetWithText(OutlinedButton, 'İptal Et'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'İptal Et'));
    await tester.pumpAndSettle();
    expect(requests.map(_path), contains('POST /manage/appointments/1/cancel'));
  });
}
