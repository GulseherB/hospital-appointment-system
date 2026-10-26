enum AppointmentStatus {
  pending,
  confirmed,
  cancelled,
  completed;

  String get apiValue => name;

  static AppointmentStatus fromApi(String value) {
    return AppointmentStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => throw ArgumentError('Unknown appointment status: $value'),
    );
  }
}
