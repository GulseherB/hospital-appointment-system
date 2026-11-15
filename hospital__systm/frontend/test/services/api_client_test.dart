import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_app/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('başarılı yanıtı çözer, token ve JSON başlıklarını ekler', () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: 'http://test/api/v1/',
      tokenProvider: () => 'abc',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'ok': 'çalıştı'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await client.post('/auth/login', {'email': 'a@b.co'});

    expect(result, {'ok': 'çalıştı'});
    expect(captured.url.toString(), 'http://test/api/v1/auth/login');
    expect(captured.headers['Authorization'], 'Bearer abc');
    expect(jsonDecode(captured.body), {'email': 'a@b.co'});
  });

  test('boş sorgu parametrelerini atar', () {
    final client = ApiClient(baseUrl: 'http://test/api/v1');
    final uri = client.buildUri('/appointment-slots', {'service_id': '3', 'doctor_id': null, 'x': ''});
    expect(uri.toString(), 'http://test/api/v1/appointment-slots?service_id=3');
  });

  test('sözleşmedeki hata biçimini ApiException yapar', () async {
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'SLOT_TAKEN', 'message': 'Seçilen saat artık müsait değil.'},
          }),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    expect(
      () => client.post('/appointments', {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', ApiErrorCode.slotTaken)
            .having((e) => e.message, 'message', 'Seçilen saat artık müsait değil.'),
      ),
    );
  });

  test('sunucuya ulaşılamazsa NETWORK_ERROR verir', () async {
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      httpClient: MockClient((_) async => throw http.ClientException('bağlantı yok')),
    );
    expect(
      () => client.get('/institutions'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.networkError)),
    );
  });
}
