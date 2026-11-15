import 'package:flutter/foundation.dart';

import '../models/role.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

/// Oturum durumu: kimin giriş yaptığı, geçici şifre durumu ve token.
/// Ekranlar bu sınıfı dinler; API çağrıları [AuthService] üzerindendir.
class SessionController extends ChangeNotifier {
  SessionController({required AuthService authService, required TokenStorage storage})
    : _auth = authService,
      _storage = storage;

  final AuthService _auth;
  final TokenStorage _storage;

  String? _token;
  User? _user;
  bool _mustChangePassword = false;
  bool _restoring = true;

  String? get token => _token;
  User? get user => _user;
  bool get isLoggedIn => _user != null && _token != null;
  bool get mustChangePassword => _mustChangePassword;

  /// Uygulama açılışında kayıtlı oturum kontrol ediliyor mu?
  bool get isRestoring => _restoring;

  /// Kayıtlı tokeni `/auth/me` ile doğrular. Geçersizse oturumu temizler.
  Future<void> restore() async {
    try {
      final saved = await _storage.read();
      if (saved == null) return;
      _token = saved;
      final result = await _auth.me();
      _user = result.user;
      _mustChangePassword = result.mustChangePassword;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _clear();
      } else {
        // Sunucuya ulaşılamadı: token silinmez, kullanıcı girişe yönlendirilir.
        _token = null;
        _user = null;
      }
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  /// Giriş yapar. Gelen rol [allowedRoles] içinde değilse oturum açılmaz ve hata verilir.
  Future<void> login(String email, String password, Set<UserRole> allowedRoles) async {
    final result = await _auth.login(email, password);
    if (!allowedRoles.contains(result.user.role)) {
      throw ApiException(
        statusCode: 403,
        code: ApiErrorCode.forbidden,
        message: 'Bu hesap bir ${result.user.role.label} hesabı. Lütfen doğru giriş seçeneğini kullanın.',
      );
    }
    await _apply(result);
  }

  Future<void> register(PatientRegistration data) async => _apply(await _auth.register(data));

  Future<void> changePassword(String currentPassword, String newPassword) async =>
      _apply(await _auth.changePassword(currentPassword, newPassword));

  Future<void> logout() async {
    await _clear();
    notifyListeners();
  }

  /// Sunucu oturumun geçersiz olduğunu bildirdiğinde (401) çağrılır.
  Future<void> handleUnauthorized() => logout();

  Future<void> _apply(AuthResult result) async {
    final token = result.token;
    if (token == null) {
      throw StateError('Sunucu yanıtında token yok.');
    }
    _token = token;
    _user = result.user;
    _mustChangePassword = result.mustChangePassword;
    await _storage.write(token);
    notifyListeners();
  }

  Future<void> _clear() async {
    _token = null;
    _user = null;
    _mustChangePassword = false;
    await _storage.clear();
  }
}
