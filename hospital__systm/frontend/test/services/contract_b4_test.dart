import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_app/models/app_notification.dart';
import 'package:hospital_app/models/appointment.dart';
import 'package:hospital_app/models/role.dart';
import 'package:hospital_app/services/api_client.dart';
import 'package:hospital_app/services/appointment_service.dart';
import 'package:hospital_app/services/manage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// B4'te canlı backend'den `curl` ile alınan yanıtlar (sözleşme uyumu testi).
const _appointment =
    '{"id":1,"status":"pending","start_at":"2026-11-16T09:00:00","end_at":"2026-11-16T09:15:00","service_id":1,'
    '"service_name":"Genel Muayene","duration_min":15,"price":"750.00","doctor_id":3,"doctor_name":"Ayşe Demir",'
    '"patient_id":5,"patient_name":"Ali Örnek","branch_name":"Merkez","institution_name":"Demo Sağlık Kliniği",'
    '"cancelled_by":null,"cancelled_at":null,"created_at":"2026-11-13T14:00:00"}';
const _cancelledByDoctor =
    '{"id":1,"status":"cancelled","start_at":"2026-11-16T09:00:00","end_at":"2026-11-16T09:15:00","service_id":1,'
    '"service_name":"Genel Muayene","duration_min":15,"price":"750.00","doctor_id":3,"doctor_name":"Ayşe Demir",'
    '"patient_id":5,"patient_name":"Ali Örnek","branch_name":"Merkez","institution_name":"Demo Sağlık Kliniği",'
    '"cancelled_by":"doctor","cancelled_at":"2026-11-13T14:00:23","created_at":"2026-11-13T14:00:00"}';
const _slots =
    '{"items":[{"doctor_id":3,"doctor_name":"Ayşe Demir","start_at":"2026-11-16T09:00:00","end_at":"2026-11-16T09:15:00"},'
    '{"doctor_id":3,"doctor_name":"Ayşe Demir","start_at":"2026-11-16T09:15:00","end_at":"2026-11-16T09:30:00"}]}';
const _notifications =
    '{"items":[{"id":1,"appointment_id":1,"type":"appointment_approved","message":"Dr. Ayşe Demir, 16.11.2026 09:00 '
    'tarihli Genel Muayene randevunuzu onayladı.","is_read":false,"created_at":"2026-11-13T14:00:22"}],"unread_count":1}';

void main() {
  late List<http.Request> requests;

  ApiClient client(String Function(http.Request) respond) {
    requests = [];
    return ApiClient(
      baseUrl: 'http://test/api/v1',
      httpClient: MockClient((req) async {
        requests.add(req);
        return http.Response(respond(req), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
  }

  test('randevu yanıtı okunur; oluşturma sözleşmedeki gövdeyi gönderir', () async {
    final service = PatientService(client((_) => _appointment));
    final slot = AppointmentSlot(
      doctorId: 3,
      doctorName: 'Ayşe Demir',
      startAt: DateTime(2026, 11, 16, 9),
      endAt: DateTime(2026, 11, 16, 9, 15),
    );
    final a = await service.book(serviceId: 1, slot: slot);
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/appointments');
    expect(jsonDecode(requests.single.body), {'service_id': 1, 'doctor_id': 3, 'start_at': '2026-11-16T09:00:00'});
    expect(a.status, AppointmentStatus.pending);
    expect(a.startAt, DateTime(2026, 11, 16, 9));
    expect(a.priceLabel, '750,00 ₺');
    expect(a.institutionName, 'Demo Sağlık Kliniği');
    expect(a.cancelledBy, isNull);
    expect(a.canBeDecided, isTrue);
  });

  test('iptal yanıtı: cancelled_by ve cancelled_at okunur', () async {
    final service = DoctorService(client((_) => _cancelledByDoctor));
    final a = await service.cancel(1);
    expect(requests.single.url.path, '/api/v1/doctor/appointments/1/cancel');
    expect(a.status, AppointmentStatus.cancelled);
    expect(a.cancelledBy, CancelledBy.doctor);
    expect(a.cancelledAt, DateTime(2026, 11, 13, 14, 0, 23));
    expect(a.canBeCancelledBy(UserRole.patient, DateTime(2026, 11, 14)), isFalse);
  });

  test('slot sorgusu: parametreler ve yanıt', () async {
    final service = PatientService(client((_) => _slots));
    final slots = await service.slots(1, doctorId: 3, dateFrom: DateTime(2026, 11, 16), dateTo: DateTime(2026, 11, 20));
    expect(requests.single.url.path, '/api/v1/appointment-slots');
    expect(requests.single.url.queryParameters, {
      'service_id': '1',
      'doctor_id': '3',
      'date_from': '2026-11-16',
      'date_to': '2026-11-20',
    });
    expect(slots.length, 2);
    expect(slots[1].startAt, DateTime(2026, 11, 16, 9, 15));
    await service.slots(1);
    expect(requests.last.url.queryParameters, {'service_id': '1'});
  });

  test('bildirim listesi, okundu ve tümü okundu', () async {
    final service = NotificationService(
      client((req) {
        if (req.url.path.endsWith('/read-all')) return '{"updated":1}';
        if (req.url.path.endsWith('/read')) {
          return '{"id":1,"appointment_id":1,"type":"appointment_approved","message":"x","is_read":true,'
              '"created_at":"2026-11-13T14:00:22"}';
        }
        return _notifications;
      }),
    );
    final page = await service.list(unreadOnly: true);
    expect(requests.last.url.query, 'unread=true');
    expect(page.unreadCount, 1);
    expect(page.items.single.type, NotificationType.approved);
    expect(page.items.single.message, contains('onayladı'));
    await service.list();
    expect(requests.last.url.query, isEmpty);
    expect((await service.markRead(1)).isRead, isTrue);
    expect(requests.last.url.path, '/api/v1/my-notifications/1/read');
    expect(await service.markAllRead(), 1);
  });

  test('doktor ve yönetici listeleri filtreleri sorguya koyar', () async {
    final api = client((_) => '{"items":[$_appointment]}');
    await DoctorService(api).appointments(status: AppointmentStatus.pending, date: DateTime(2026, 11, 16));
    expect(requests.last.url.path, '/api/v1/doctor/appointments');
    expect(requests.last.url.queryParameters, {'status': 'pending', 'date': '2026-11-16'});
    final list = await ManageService(api).listAppointments(doctorId: 3, status: AppointmentStatus.approved);
    expect(requests.last.url.path, '/api/v1/manage/appointments');
    expect(requests.last.url.queryParameters, {'doctor_id': '3', 'status': 'approved'});
    expect(list.single.patientName, 'Ali Örnek');
    final cancelled = await ManageService(client((_) => _cancelledByDoctor)).cancelAppointment(1);
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/manage/appointments/1/cancel');
    expect(cancelled.status, AppointmentStatus.cancelled);
  });

  test('BookingRules: öğle arası, 24 saat ve 7 gün', () {
    final now = DateTime(2026, 11, 13, 14, 0); // Cuma
    AppointmentSlot slot(DateTime start, int minutes) => AppointmentSlot(
      doctorId: 1,
      doctorName: 'A',
      startAt: start,
      endAt: start.add(Duration(minutes: minutes)),
    );
    expect(BookingRules.allows(slot(DateTime(2026, 11, 16, 11, 45), 15), now), isTrue);
    expect(BookingRules.allows(slot(DateTime(2026, 11, 16, 11, 45), 30), now), isFalse, reason: '12:15 öğleye taşar');
    expect(BookingRules.allows(slot(DateTime(2026, 11, 16, 12, 30), 15), now), isFalse);
    expect(BookingRules.allows(slot(DateTime(2026, 11, 16, 13, 0), 15), now), isTrue);
    expect(BookingRules.allows(slot(DateTime(2026, 11, 14, 13, 59), 15), now), isFalse, reason: '24 saatten yakın');
    expect(BookingRules.allows(slot(DateTime(2026, 11, 20, 16, 45), 15), now), isTrue, reason: 'bugün + 7');
    expect(BookingRules.allows(slot(DateTime(2026, 11, 21, 9, 0), 15), now), isFalse, reason: 'ufuk dışı');
  });
}
