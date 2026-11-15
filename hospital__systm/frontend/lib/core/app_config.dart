/// Uygulama ayarları. API adresi derleme sırasında değiştirilebilir:
/// `flutter run --dart-define=API_BASE_URL=http://localhost:8080/api/v1`
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080/api/v1');

  static const Duration requestTimeout = Duration(seconds: 15);
}
