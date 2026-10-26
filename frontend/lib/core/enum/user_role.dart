enum UserRole {
  patient,
  doctor,
  healthStaff,
  hospitalManager;

  String get apiValue => name;

  static UserRole fromApi(String value) {
    return UserRole.values.firstWhere(
      (role) => role.apiValue == value,
      orElse: () => throw ArgumentError('Unknown user role: $value'),
    );
  }
}
