import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';

/// API hata kodları (API sözleşmesi → Hata biçimi). İstemci tarafı kodlar ayrıca işaretlidir.
class ApiErrorCode {
  ApiErrorCode._();

  static const invalidRequest = 'INVALID_REQUEST';
  static const unauthorized = 'UNAUTHORIZED';
  static const forbidden = 'FORBIDDEN';
  static const passwordChangeRequired = 'PASSWORD_CHANGE_REQUIRED';
  static const applicationPending = 'APPLICATION_PENDING';
  static const applicationRejected = 'APPLICATION_REJECTED';
  static const notFound = 'NOT_FOUND';
  static const slotTaken = 'SLOT_TAKEN';
  static const nationalIdExists = 'NATIONAL_ID_EXISTS';
  static const emailExists = 'EMAIL_EXISTS';
  static const patientConflict = 'PATIENT_CONFLICT';
  static const hasFutureAppointments = 'HAS_FUTURE_APPOINTMENTS';
  static const businessRuleViolation = 'BUSINESS_RULE_VIOLATION';

  /// İstemci tarafı: sunucuya ulaşılamadı.
  static const networkError = 'NETWORK_ERROR';

  /// İstemci tarafı: sunucu yanıtı beklenen biçimde değil.
  static const unexpectedResponse = 'UNEXPECTED_RESPONSE';
}

/// API çağrısı hatası. [message] kullanıcıya gösterilebilecek Türkçe metindir.
class ApiException implements Exception {
  ApiException({required this.statusCode, required this.code, required this.message});

  /// HTTP durum kodu; ağ hatasında 0.
  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// JSON tabanlı HTTP istemcisi. Token ekler, hataları [ApiException]'a çevirir.
/// Ekranlar bu sınıfı doğrudan değil, servis sınıfları üzerinden kullanır.
class ApiClient {
  ApiClient({http.Client? httpClient, String baseUrl = AppConfig.apiBaseUrl, String? Function()? tokenProvider})
    : _http = httpClient ?? http.Client(),
      _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
      _tokenProvider = tokenProvider;

  final http.Client _http;
  final String _baseUrl;
  String? Function()? _tokenProvider;

  /// Token gönderilmiş bir istek 401 aldığında çağrılır (oturum süresi doldu).
  void Function()? onUnauthorized;

  /// Oturum servisi token kaynağını sonradan bağlayabilir.
  set tokenProvider(String? Function()? provider) => _tokenProvider = provider;

  Future<dynamic> get(String path, {Map<String, String?>? query}) => _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);

  Uri buildUri(String path, [Map<String, String?>? query]) {
    final cleaned = <String, String>{};
    query?.forEach((key, value) {
      if (value != null && value.isNotEmpty) cleaned[key] = value;
    });
    final uri = Uri.parse('$_baseUrl$path');
    return cleaned.isEmpty ? uri : uri.replace(queryParameters: cleaned);
  }

  Future<dynamic> _send(String method, String path, {Map<String, String?>? query, Object? body}) async {
    final request = http.Request(method, buildUri(path, query));
    request.headers['Accept'] = 'application/json';
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(AppConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        code: ApiErrorCode.networkError,
        message: 'Sunucu yanıt vermedi. Lütfen tekrar deneyin.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        code: ApiErrorCode.networkError,
        message: 'Sunucuya ulaşılamadı. Backend çalışıyor mu?',
      );
    }

    final decoded = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (response.statusCode == 401 && token != null && token.isNotEmpty) {
      onUnauthorized?.call();
    }
    throw _toException(response.statusCode, decoded);
  }

  dynamic _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    if (text.trim().isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      throw ApiException(
        statusCode: response.statusCode,
        code: ApiErrorCode.unexpectedResponse,
        message: 'Sunucudan beklenmeyen yanıt alındı.',
      );
    }
  }

  ApiException _toException(int statusCode, dynamic decoded) {
    if (decoded is Map<String, dynamic> && decoded['error'] is Map<String, dynamic>) {
      final error = decoded['error'] as Map<String, dynamic>;
      return ApiException(
        statusCode: statusCode,
        code: (error['code'] as String?) ?? ApiErrorCode.unexpectedResponse,
        message: (error['message'] as String?) ?? 'Bilinmeyen bir hata oluştu.',
      );
    }
    return ApiException(
      statusCode: statusCode,
      code: ApiErrorCode.unexpectedResponse,
      message: 'Sunucudan beklenmeyen yanıt alındı (HTTP $statusCode).',
    );
  }

  void close() => _http.close();
}
