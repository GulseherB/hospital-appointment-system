enum AppointmentStatus {
  pending,
  confirmed,
  rejected,
  cancelled,
  completed,
  noShow;

  String get apiValue => switch (this) {
    AppointmentStatus.pending => 'pending',
    AppointmentStatus.confirmed => 'confirmed',
    AppointmentStatus.rejected => 'rejected',
    AppointmentStatus.cancelled => 'cancelled',
    AppointmentStatus.completed => 'completed',
    AppointmentStatus.noShow => 'no_show',
  };

  static AppointmentStatus fromApi(String value) {
    return AppointmentStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => throw ArgumentError('Unknown appointment status: $value'),
    );
  }
}
