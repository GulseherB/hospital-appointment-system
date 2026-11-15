import 'package:shared_preferences/shared_preferences.dart';

/// Oturum tokeninin kalıcı saklanması. Testlerde [MemoryTokenStorage] kullanılır.
abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Cihazda (web'de tarayıcı deposunda) saklar.
class PreferencesTokenStorage implements TokenStorage {
  static const _key = 'auth_token';

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String token) async => (await SharedPreferences.getInstance()).setString(_key, token);

  @override
  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}

/// Bellekte saklar (testler için).
class MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
