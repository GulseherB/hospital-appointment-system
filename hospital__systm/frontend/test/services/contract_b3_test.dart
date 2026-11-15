import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_app/models/clock_time.dart';
import 'package:hospital_app/models/institution.dart';
import 'package:hospital_app/models/institution_application.dart';
import 'package:hospital_app/services/api_client.dart';
import 'package:hospital_app/services/institution_service.dart';
import 'package:hospital_app/services/manage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// B3'te canlı backend'den `curl` ile alınan yanıtlar (sözleşme uyumu testi).
const _application =
    '{"id":3,"status":"approved","institution":{"name":"Test Hastanesi","type":"hospital","address":"Test Cad. 5",'
    '"phone":"02161112233","email":"info@test.local"},"admin":{"first_name":"Ece","last_name":"Kurt",'
    '"email":"ece@test.local","phone":"05321112233"},"institution_id":2,"created_at":"2026-11-13T11:54:19",'
    '"decided_at":"2026-11-13T11:54:20"}';
const _createdDoctor =
    '{"id":8,"first_name":"Can","last_name":"Ak","email":"can@test.local","phone":"05330000000","branch_id":2,'
    '"department_id":3,"specialty":"Kardiyoloji","is_active":true,"service_ids":[],"temporary_password":"5TJZnTJ2LCYM"}';
const _service = '{"id":5,"department_id":3,"name":"EKG","duration_min":20,"price":"450.50","is_active":true}';
const _availability =
    '{"items":[{"weekday":1,"start_time":"09:00","end_time":"17:00"},{"weekday":3,"start_time":"09:00","end_time":"12:00"}]}';

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

  test('başvuru yanıtı okunur, onay doğru yola gider', () async {
    final service = InstitutionService(client((_) => _application));
    final app = await service.approve(3);
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/admin/applications/3/approve');
    expect(app.status, ApplicationStatus.approved);
    expect(app.institutionType, InstitutionType.hospital);
    expect(app.adminFullName, 'Ece Kurt');
    expect(app.canBeDecided, isFalse);
    expect(app.decidedAt, DateTime(2026, 11, 13, 11, 54, 20));
  });

  test('başvuru formu sözleşmedeki iç içe gövdeyi gönderir', () async {
    final service = InstitutionService(client((_) => _application.replaceFirst('approved', 'pending')));
    await service.apply(
      ApplicationForm(
        institutionName: ' Test Hastanesi ',
        institutionType: InstitutionType.hospital,
        institutionAddress: 'Test Cad. 5',
        institutionPhone: '02161112233',
        institutionEmail: 'info@test.local',
        adminFirstName: 'Ece',
        adminLastName: 'Kurt',
        adminEmail: 'ece@test.local',
        adminPhone: '05321112233',
        adminPassword: 'Ece_Sifre_1',
      ),
    );
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body.keys, unorderedEquals(['institution', 'admin']));
    expect(body['institution'], {
      'name': 'Test Hastanesi',
      'type': 'hospital',
      'address': 'Test Cad. 5',
      'phone': '02161112233',
      'email': 'info@test.local',
    });
    expect((body['admin'] as Map).keys, unorderedEquals(['first_name', 'last_name', 'email', 'phone', 'password']));
  });

  test('başvuru filtresi status sorgusuyla gider', () async {
    final service = InstitutionService(client((_) => '{"items":[$_application]}'));
    await service.listApplications(status: ApplicationStatus.pending);
    await service.listApplications();
    expect(requests[0].url.query, 'status=pending');
    expect(requests[1].url.query, isEmpty);
  });

  test('doktor oluşturma: geçici şifre ve doktor okunur', () async {
    final service = ManageService(client((_) => _createdDoctor));
    final created = await service.createDoctor(
      branchId: 2,
      departmentId: 3,
      firstName: 'Can',
      lastName: 'Ak',
      email: 'can@test.local',
      phone: '05330000000',
      specialty: 'Kardiyoloji',
    );
    expect(created.temporaryPassword, '5TJZnTJ2LCYM');
    expect(created.doctor.doctor.displayName, 'Dr. Can Ak');
    expect(created.doctor.doctor.departmentId, 3);
    expect(created.doctor.serviceIds, isEmpty);
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['branch_id'], 2);
    expect(body['department_id'], 3);
  });

  test('hizmet: ücret metin olarak gider ve gelir', () async {
    final service = ManageService(client((_) => _service));
    final s = await service.createService(departmentId: 3, name: 'EKG', durationMin: 20, price: '450.5');
    expect((jsonDecode(requests.single.body) as Map)['price'], '450.5');
    expect(s.price, '450.50');
    expect(s.priceLabel, '450,50 ₺');
  });

  test('uygunluk: HH:MM biçiminde gider ve gelir', () async {
    final service = ManageService(client((_) => _availability));
    final saved = await service.setAvailability(8, [
      WeeklyTimeRange(weekday: 1, start: ClockTime(9, 0), end: ClockTime(17, 0)),
    ]);
    expect(requests.single.method, 'PUT');
    expect(jsonDecode(requests.single.body), {
      'items': [
        {'weekday': 1, 'start_time': '09:00', 'end_time': '17:00'},
      ],
    });
    expect(saved.length, 2);
    expect(saved[1].end, ClockTime(12, 0));
  });

  test('bölüm listesi branch_id filtresi', () async {
    final service = ManageService(
      client((_) => '{"items":[{"id":3,"branch_id":2,"name":"Kardiyoloji","is_active":true}]}'),
    );
    final list = await service.listDepartments(branchId: 2);
    expect(requests.single.url.query, 'branch_id=2');
    expect(list.single.name, 'Kardiyoloji');
  });
}
