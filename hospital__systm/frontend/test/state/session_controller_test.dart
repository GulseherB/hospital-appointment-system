import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_app/models/role.dart';
import 'package:hospital_app/models/user.dart';
import 'package:hospital_app/services/api_client.dart';
import 'package:hospital_app/services/auth_service.dart';
import 'package:hospital_app/services/token_storage.dart';
import 'package:hospital_app/state/session_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _session(String role, {bool mustChange = false}) => {
  'token': 'tok-$role',
  'must_change_password': mustChange,
  'user': {'id': 4, 'role': role, 'first_name': 'Mehmet', 'last_name': 'Kaya', 'email': 'doctor2@demo.local'},
};

void main() {
  late MemoryTokenStorage storage;

  SessionController build(Future<http.Response> Function(http.Request) handler) {
    late SessionController session;
    final api = ApiClient(baseUrl: 'http://test/api/v1', httpClient: MockClient(handler));
    session = SessionController(authService: AuthService(api), storage: storage);
    api.tokenProvider = () => session.token;
    return session;
  }

  setUp(() => storage = MemoryTokenStorage());

  test('başarılı giriş tokeni saklar ve doğru alt sınıfı kurar', () async {
    final session = build((_) async => _json(_session('doctor'), 200));
    await session.login('doctor2@demo.local', 'x', {UserRole.doctor});
    expect(session.isLoggedIn, isTrue);
    expect(session.user, isA<Doctor>());
    expect(await storage.read(), 'tok-doctor');
  });

  test('seçilen giriş türüyle rol uyuşmazsa oturum açılmaz', () async {
    final session = build((_) async => _json(_session('doctor'), 200));
    await expectLater(
      session.login('doctor2@demo.local', 'x', {UserRole.patient}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.forbidden)),
    );
    expect(session.isLoggedIn, isFalse);
    expect(await storage.read(), isNull);
  });

  test('geçici şifre işareti taşınır, değişince kalkar', () async {
    var changed = false;
    final session = build((req) async {
      if (req.url.path.endsWith('/auth/change-password')) {
        changed = true;
        return _json(_session('doctor'), 200);
      }
      return _json(_session('doctor', mustChange: true), 200);
    });
    await session.login('doctor2@demo.local', 'x', {UserRole.doctor});
    expect(session.mustChangePassword, isTrue);
    await session.changePassword('eski_sifre1', 'yeni_sifre1');
    expect(changed, isTrue);
    expect(session.mustChangePassword, isFalse);
  });

  test('kayıtlı token 401 alırsa temizlenir', () async {
    await storage.write('eski');
    final session = build(
      (_) async => _json({
        'error': {'code': 'UNAUTHORIZED', 'message': 'Oturum geçersiz.'},
      }, 401),
    );
    await session.restore();
    expect(session.isRestoring, isFalse);
    expect(session.isLoggedIn, isFalse);
    expect(await storage.read(), isNull);
  });

  test('kayıtlı token geçerliyse oturum geri yüklenir', () async {
    await storage.write('tok-patient');
    final session = build((req) async {
      expect(req.headers['Authorization'], 'Bearer tok-patient');
      final body = _session('patient')..remove('token');
      return _json(body, 200);
    });
    await session.restore();
    expect(session.isLoggedIn, isTrue);
    expect(session.user, isA<Patient>());
  });
}
