import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_app/services/api_client.dart';
import 'package:hospital_app/services/institution_service.dart';
import 'package:hospital_app/services/manage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// B5'te canlı backend'den `curl` ile alınan yanıtların biçimi (sözleşme uyumu testi).
const _service =
    '{"id":1,"department_id":1,"name":"Genel Muayene","duration_min":20,"price":"800.00","is_active":true}';
const _doctorUpdate =
    '{"id":12,"first_name":"Test","last_name":"Doktor","email":"b5doc@test.local","phone":"05000000010","branch_id":8,'
    '"department_id":7,"specialty":"","is_active":true,"service_ids":[],"removed_service_ids":[7],"availability_cleared":true}';
const _adminReset =
    '{"institution_id":4,"admin_first_name":"Bes","admin_last_name":"Admin","admin_email":"b5admin@test.local",'
    '"temporary_password":"Xy7kP2mQ9aBc"}';
const _institution =
    '{"id":1,"name":"Demo Sağlık Kliniği","type":"clinic","address":"Örnek Mah.","phone":"02120000000",'
    '"email":"info@demo.local","is_active":false}';

void main() {
  late List<http.Request> requests;

  ApiClient client(String body) {
    requests = [];
    return ApiClient(
      baseUrl: 'http://test/api/v1',
      httpClient: MockClient((req) async {
        requests.add(req);
        return http.Response(body, 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
  }

  test('hizmet güncelleme: PUT tüm alanları ve is_active gönderir', () async {
    final s = await ManageService(
      client(_service),
    ).updateService(1, name: ' Genel Muayene ', durationMin: 20, price: '800.00', isActive: true);
    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/api/v1/manage/services/1');
    expect(jsonDecode(requests.single.body), {
      'name': 'Genel Muayene',
      'duration_min': 20,
      'price': '800.00',
      'is_active': true,
    });
    expect(s.priceLabel, '800,00 ₺');
  });

  test('şube ve bölüm güncelleme gövdeleri', () async {
    final api = client('{"id":2,"institution_id":1,"name":"Ş","address":"","phone":"","is_active":false}');
    await ManageService(api).updateBranch(2, name: 'Ş', address: '', phone: '', isActive: false);
    expect(requests.last.url.path, '/api/v1/manage/branches/2');
    expect(jsonDecode(requests.last.body), {'name': 'Ş', 'address': '', 'phone': '', 'is_active': false});
    final api2 = client('{"id":3,"branch_id":2,"name":"B","is_active":true}');
    final d = await ManageService(api2).updateDepartment(3, name: 'B', isActive: true);
    expect(jsonDecode(requests.last.body), {'name': 'B', 'is_active': true});
    expect(d.branchId, 2);
  });

  test('doktor güncelleme: kaldırılan hizmetler ve silinen uygunluk okunur', () async {
    final r = await ManageService(client(_doctorUpdate)).updateDoctor(
      12,
      branchId: 8,
      departmentId: 7,
      firstName: 'Test',
      lastName: 'Doktor',
      phone: '05000000010',
      specialty: '',
      isActive: true,
    );
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(
      body.keys,
      unorderedEquals(['first_name', 'last_name', 'phone', 'specialty', 'branch_id', 'department_id', 'is_active']),
    );
    expect(body.containsKey('email'), isFalse, reason: 'e-posta değiştirilemez');
    expect(r.removedServiceIds, [7]);
    expect(r.availabilityCleared, isTrue);
    expect(r.doctor.doctor.branchId, 8);
    expect(r.doctor.serviceIds, isEmpty);
  });

  test('doktor şifre sıfırlama: geçici şifre okunur', () async {
    final r = await ManageService(
      client(
        _doctorUpdate.replaceFirst(
          '"removed_service_ids":[7],"availability_cleared":true',
          '"temporary_password":"T3mp"',
        ),
      ),
    ).resetDoctorPassword(12);
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/manage/doctors/12/reset-password');
    expect(r.temporaryPassword, 'T3mp');
  });

  test('kurum pasifleştirme PATCH ve yönetici şifre sıfırlama', () async {
    final inst = await InstitutionService(client(_institution)).setInstitutionActive(1, false);
    expect(requests.single.method, 'PATCH');
    expect(requests.single.url.path, '/api/v1/admin/institutions/1');
    expect(jsonDecode(requests.single.body), {'is_active': false});
    expect(inst.isActive, isFalse);

    final reset = await InstitutionService(client(_adminReset)).resetAdminPassword(4);
    expect(requests.single.url.path, '/api/v1/admin/institutions/4/reset-admin-password');
    expect(reset.adminName, 'Bes Admin');
    expect(reset.adminEmail, 'b5admin@test.local');
    expect(reset.temporaryPassword, 'Xy7kP2mQ9aBc');
  });
}
