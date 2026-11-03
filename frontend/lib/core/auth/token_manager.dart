class TokenManager {
  String? _token;

  String? get token => _token;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  void save(String token) {
    if (token.trim().isEmpty) {
      throw ArgumentError.value(token, 'token', 'Token cannot be empty');
    }
    _token = token;
  }

  void clear() {
    _token = null;
  }
}
