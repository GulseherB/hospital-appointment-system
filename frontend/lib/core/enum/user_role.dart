enum UserRole {
  patient,
  doctor,
  healthStaff,
  hospitalManager;

  String get apiValue => switch (this) {
    UserRole.patient => 'patient',
    UserRole.doctor => 'doctor',
    UserRole.healthStaff => 'health_staff',
    UserRole.hospitalManager => 'hospital_manager',
  };

  static UserRole fromApi(String value) {
    return UserRole.values.firstWhere(
      (role) => role.apiValue == value,
      orElse: () => throw ArgumentError('Unknown user role: $value'),
    );
  }
}
