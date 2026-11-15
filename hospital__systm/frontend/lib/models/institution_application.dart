import '../core/date_utils.dart';
import 'contracts.dart';
import 'institution.dart';

enum ApplicationStatus {
  pending('pending', 'Beklemede'),
  approved('approved', 'Onaylandı'),
  rejected('rejected', 'Reddedildi');

  const ApplicationStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ApplicationStatus fromApi(String value) => ApplicationStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => throw FormatException('Bilinmeyen başvuru durumu: $value'),
  );
}

/// Kurum başvurusu. Süper admin yalnızca bekleyen başvuruya karar verir.
class InstitutionApplication implements Approvable {
  InstitutionApplication({
    required this.id,
    required this.status,
    required this.institutionName,
    required this.institutionType,
    required this.institutionAddress,
    required this.institutionPhone,
    required this.institutionEmail,
    required this.adminFirstName,
    required this.adminLastName,
    required this.adminEmail,
    required this.adminPhone,
    required this.createdAt,
    this.decidedAt,
  });

  final int id;
  final ApplicationStatus status;
  final String institutionName;
  final InstitutionType institutionType;
  final String institutionAddress;
  final String institutionPhone;
  final String institutionEmail;
  final String adminFirstName;
  final String adminLastName;
  final String adminEmail;
  final String adminPhone;
  final DateTime createdAt;
  final DateTime? decidedAt;

  String get adminFullName => '$adminFirstName $adminLastName';

  @override
  bool get canBeDecided => status == ApplicationStatus.pending;

  factory InstitutionApplication.fromJson(Map<String, dynamic> json) {
    final institution = json['institution'] as Map<String, dynamic>;
    final admin = json['admin'] as Map<String, dynamic>;
    return InstitutionApplication(
      id: json['id'] as int,
      status: ApplicationStatus.fromApi(json['status'] as String),
      institutionName: institution['name'] as String,
      institutionType: InstitutionType.fromApi(institution['type'] as String),
      institutionAddress: institution['address'] as String,
      institutionPhone: institution['phone'] as String,
      institutionEmail: institution['email'] as String,
      adminFirstName: admin['first_name'] as String,
      adminLastName: admin['last_name'] as String,
      adminEmail: admin['email'] as String,
      adminPhone: admin['phone'] as String,
      createdAt: ApiDate.parseDateTime(json['created_at'] as String),
      decidedAt: ApiDate.parseDateTimeOrNull(json['decided_at']),
    );
  }
}
