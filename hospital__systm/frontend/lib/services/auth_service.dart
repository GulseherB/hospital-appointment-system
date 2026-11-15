import '../models/user.dart';
import 'api_client.dart';

/// Giriş, kayıt ve şifre değiştirme yanıtı.
class AuthResult {
  AuthResult({required this.user, required this.mustChangePassword, this.token});

  final User user;
  final bool mustChangePassword;

  /// `/auth/me` yanıtında token yoktur.
  final String? token;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    user: User.fromJson(json['user'] as Map<String, dynamic>),
    mustChangePassword: json['must_change_password'] as bool,
    token: json['token'] as String?,
  );
}

/// Hasta kaydı formunun verisi.
class PatientRegistration {
  PatientRegistration({
    required this.firstName,
    required this.lastName,
    required this.nationalId,
    required this.email,
    required this.phone,
    required this.password,
  });

  final String firstName;
  final String lastName;
  final String nationalId;
  final String email;
  final String phone;
  final String password;

  Map<String, dynamic> toJson() => {
    'first_name': firstName.trim(),
    'last_name': lastName.trim(),
    'national_id': nationalId.trim(),
    'email': email.trim(),
    'phone': phone.trim(),
    'password': password,
  };
}

/// `/auth/*` uç noktalarının istemcisi (API sözleşmesi → Kimlik ve kayıt).
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<AuthResult> login(String email, String password) async {
    final json = await _api.post('/auth/login', {'email': email.trim(), 'password': password});
    return AuthResult.fromJson(json as Map<String, dynamic>);
  }

  Future<AuthResult> register(PatientRegistration data) async {
    final json = await _api.post('/auth/register', data.toJson());
    return AuthResult.fromJson(json as Map<String, dynamic>);
  }

  Future<AuthResult> changePassword(String currentPassword, String newPassword) async {
    final json = await _api.post('/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    return AuthResult.fromJson(json as Map<String, dynamic>);
  }

  Future<AuthResult> me() async {
    final json = await _api.get('/auth/me');
    return AuthResult.fromJson(json as Map<String, dynamic>);
  }
}
