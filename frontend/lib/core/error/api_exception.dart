import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  factory ApiException.fromDio(DioException exception) {
    final data = exception.response?.data;
    if (data is Map && data['error'] is String) {
      return ApiException(data['error'] as String);
    }
    if (exception.type == DioExceptionType.connectionError) {
      return const ApiException(
        'Backend bağlantısı kurulamadı. Backend servisinin çalıştığını kontrol edin.',
      );
    }
    if (exception.type == DioExceptionType.connectionTimeout ||
        exception.type == DioExceptionType.receiveTimeout) {
      return const ApiException(
        'Backend yanıt vermedi. Lütfen tekrar deneyin.',
      );
    }
    return ApiException(
      'İstek başarısız oldu (${exception.response?.statusCode ?? 'bilinmeyen hata'}).',
    );
  }

  @override
  String toString() => message;
}
