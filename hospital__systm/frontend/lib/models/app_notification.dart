import '../core/date_utils.dart';

/// Bildirim türleri. [apiValue] API sözleşmesindeki değerdir.
enum NotificationType {
  approved('appointment_approved'),
  rejected('appointment_rejected'),
  cancelledByDoctor('appointment_cancelled_by_doctor'),
  cancelledByAdmin('appointment_cancelled_by_admin'),
  cancelledAuto('appointment_cancelled_auto');

  const NotificationType(this.apiValue);

  final String apiValue;

  bool get isPositive => this == approved;

  static NotificationType fromApi(String value) => NotificationType.values.firstWhere(
    (t) => t.apiValue == value,
    orElse: () => throw FormatException('Bilinmeyen bildirim türü: $value'),
  );
}

/// Hastaya düşen uygulama içi bildirim. (Flutter'ın Notification sınıfıyla karışmaması için bu ad seçildi.)
class AppNotification {
  AppNotification({
    required this.id,
    required this.appointmentId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final int appointmentId;
  final NotificationType type;

  /// Sunucunun ürettiği Türkçe mesaj.
  final String message;
  final bool isRead;
  final DateTime createdAt;

  AppNotification markedRead() => AppNotification(
    id: id,
    appointmentId: appointmentId,
    type: type,
    message: message,
    isRead: true,
    createdAt: createdAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as int,
    appointmentId: json['appointment_id'] as int,
    type: NotificationType.fromApi(json['type'] as String),
    message: json['message'] as String,
    isRead: json['is_read'] as bool,
    createdAt: ApiDate.parseDateTime(json['created_at'] as String),
  );
}
