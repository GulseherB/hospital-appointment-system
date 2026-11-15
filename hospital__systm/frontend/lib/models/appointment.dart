import '../core/date_utils.dart';
import 'contracts.dart';
import 'institution.dart';
import 'role.dart';

/// Randevu durumları. [apiValue] API sözleşmesindeki değerdir.
enum AppointmentStatus {
  pending('pending', 'Onay Bekliyor'),
  approved('approved', 'Onaylandı'),
  rejected('rejected', 'Reddedildi'),
  cancelled('cancelled', 'İptal Edildi'),
  completed('completed', 'Tamamlandı');

  const AppointmentStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Aktif randevular slotu tutar ve iptal edilebilir.
  bool get isActive => this == pending || this == approved;

  static AppointmentStatus fromApi(String value) => AppointmentStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => throw FormatException('Bilinmeyen randevu durumu: $value'),
  );
}

/// İptal eden taraf.
enum CancelledBy {
  patient('patient', 'Hasta'),
  doctor('doctor', 'Doktor'),
  admin('admin', 'Kurum Yöneticisi'),
  system('system', 'Sistem (otomatik)');

  const CancelledBy(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CancelledBy? fromApi(String? value) {
    if (value == null) return null;
    return CancelledBy.values.firstWhere(
      (c) => c.apiValue == value,
      orElse: () => throw FormatException('Bilinmeyen iptal eden: $value'),
    );
  }
}

/// Randevu. İlişki (association): hasta, doktor ve hizmete id ve ad ile bağlıdır.
/// Hizmet adı, süre ve ücret randevu anındaki kopyadır.
class Appointment implements Approvable, Cancellable {
  Appointment({
    required this.id,
    required this.status,
    required DateTime startAt,
    required DateTime endAt,
    required this.serviceId,
    required this.serviceName,
    required this.durationMin,
    required this.price,
    required this.doctorId,
    required this.doctorName,
    required this.patientId,
    required this.patientName,
    this.branchName = '',
    this.institutionName = '',
    this.cancelledBy,
    this.cancelledAt,
    this.createdAt,
  }) : _startAt = startAt,
       _endAt = endAt {
    if (!startAt.isBefore(endAt)) {
      throw ArgumentError('Randevu bitişi başlangıçtan sonra olmalıdır.');
    }
  }

  final int id;
  final AppointmentStatus status;
  final DateTime _startAt;
  final DateTime _endAt;
  final int serviceId;
  final String serviceName;
  final int durationMin;
  final String price;
  final int doctorId;
  final String doctorName;
  final int patientId;
  final String patientName;
  final String branchName;
  final String institutionName;
  final CancelledBy? cancelledBy;
  final DateTime? cancelledAt;
  final DateTime? createdAt;

  DateTime get startAt => _startAt;
  DateTime get endAt => _endAt;
  String get priceLabel => formatPrice(price);

  /// Doktor yalnızca onay bekleyen randevuya karar verir.
  @override
  bool get canBeDecided => status == AppointmentStatus.pending;

  /// Genel 2 saat kuralı: aktif randevu ve başlangıca en az 2 saat var.
  @override
  bool canBeCancelledAt(DateTime now) =>
      status.isActive && _startAt.difference(now) >= Cancellable.minNoticeBeforeStart;

  /// Role göre iptal hakkı: doktor yalnızca onayladığı randevuyu iptal eder.
  bool canBeCancelledBy(UserRole role, DateTime now) {
    if (!canBeCancelledAt(now)) return false;
    return switch (role) {
      UserRole.doctor => status == AppointmentStatus.approved,
      UserRole.patient || UserRole.institutionAdmin => true,
      UserRole.superAdmin => false,
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['id'] as int,
    status: AppointmentStatus.fromApi(json['status'] as String),
    startAt: ApiDate.parseDateTime(json['start_at'] as String),
    endAt: ApiDate.parseDateTime(json['end_at'] as String),
    serviceId: json['service_id'] as int,
    serviceName: json['service_name'] as String,
    durationMin: json['duration_min'] as int,
    price: json['price'] as String,
    doctorId: json['doctor_id'] as int,
    doctorName: json['doctor_name'] as String,
    patientId: json['patient_id'] as int,
    patientName: json['patient_name'] as String,
    branchName: (json['branch_name'] as String?) ?? '',
    institutionName: (json['institution_name'] as String?) ?? '',
    cancelledBy: CancelledBy.fromApi(json['cancelled_by'] as String?),
    cancelledAt: ApiDate.parseDateTimeOrNull(json['cancelled_at']),
    createdAt: ApiDate.parseDateTimeOrNull(json['created_at']),
  );
}

/// Randevu kurallarının arayüzdeki karşılığı. Asıl kural backend'dedir; arayüz yalnızca
/// sunucudan gelen slotları bu kurallarla bir kez daha süzer ve tarih seçimini sınırlar.
class BookingRules {
  BookingRules._();

  static const minLeadTime = Duration(hours: 24);
  static const horizonDays = 7;
  static const lunchStartMinute = 12 * 60;
  static const lunchEndMinute = 13 * 60;

  /// Randevu alınabilecek son gün (bugün + 7, dahil).
  static DateTime lastBookableDay(DateTime now) => DateTime(now.year, now.month, now.day + horizonDays);

  /// Aralık 12:00–13:00 öğle arasıyla kesişiyor mu.
  static bool overlapsLunch(DateTime start, DateTime end) {
    final s = start.hour * 60 + start.minute;
    final e = end.day == start.day ? end.hour * 60 + end.minute : 24 * 60;
    return s < lunchEndMinute && e > lunchStartMinute;
  }

  /// Slot, öğle arası, 24 saat ve 7 gün kurallarına uyuyor mu.
  static bool allows(AppointmentSlot slot, DateTime now) {
    if (slot.startAt.isBefore(now.add(minLeadTime))) return false;
    final day = DateTime(slot.startAt.year, slot.startAt.month, slot.startAt.day);
    if (day.isAfter(lastBookableDay(now))) return false;
    return !overlapsLunch(slot.startAt, slot.endAt);
  }
}

/// Sunucunun ürettiği uygun randevu slotu. Hasta saat belirlemez, yalnızca bunlardan seçer.
class AppointmentSlot {
  AppointmentSlot({required this.doctorId, required this.doctorName, required this.startAt, required this.endAt});

  final int doctorId;
  final String doctorName;
  final DateTime startAt;
  final DateTime endAt;

  factory AppointmentSlot.fromJson(Map<String, dynamic> json) => AppointmentSlot(
    doctorId: json['doctor_id'] as int,
    doctorName: json['doctor_name'] as String,
    startAt: ApiDate.parseDateTime(json['start_at'] as String),
    endAt: ApiDate.parseDateTime(json['end_at'] as String),
  );
}
