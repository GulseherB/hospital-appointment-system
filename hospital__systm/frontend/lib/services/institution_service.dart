import '../models/institution.dart';
import '../models/institution_application.dart';
import 'api_client.dart';

/// Kurum başvurusu formunun verisi.
class ApplicationForm {
  ApplicationForm({
    required this.institutionName,
    required this.institutionType,
    required this.institutionAddress,
    required this.institutionPhone,
    required this.institutionEmail,
    required this.adminFirstName,
    required this.adminLastName,
    required this.adminEmail,
    required this.adminPhone,
    required this.adminPassword,
  });

  final String institutionName;
  final InstitutionType institutionType;
  final String institutionAddress;
  final String institutionPhone;
  final String institutionEmail;
  final String adminFirstName;
  final String adminLastName;
  final String adminEmail;
  final String adminPhone;
  final String adminPassword;

  Map<String, dynamic> toJson() => {
    'institution': {
      'name': institutionName.trim(),
      'type': institutionType.apiValue,
      'address': institutionAddress.trim(),
      'phone': institutionPhone.trim(),
      'email': institutionEmail.trim(),
    },
    'admin': {
      'first_name': adminFirstName.trim(),
      'last_name': adminLastName.trim(),
      'email': adminEmail.trim(),
      'phone': adminPhone.trim(),
      'password': adminPassword,
    },
  };
}

List<Map<String, dynamic>> _items(dynamic json) =>
    ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();

/// Kurum başvurusu ve süper admin uç noktaları (API sözleşmesi → Kurum başvurusu ve süper admin).
class InstitutionService {
  InstitutionService(this._api);

  final ApiClient _api;

  Future<InstitutionApplication> apply(ApplicationForm form) async => InstitutionApplication.fromJson(
    await _api.post('/institution-applications', form.toJson()) as Map<String, dynamic>,
  );

  /// [status] null ise tüm başvurular.
  Future<List<InstitutionApplication>> listApplications({ApplicationStatus? status}) async {
    final json = await _api.get('/admin/applications', query: {'status': status?.apiValue});
    return _items(json).map(InstitutionApplication.fromJson).toList();
  }

  Future<InstitutionApplication> approve(int id) async =>
      InstitutionApplication.fromJson(await _api.post('/admin/applications/$id/approve') as Map<String, dynamic>);

  Future<InstitutionApplication> reject(int id) async =>
      InstitutionApplication.fromJson(await _api.post('/admin/applications/$id/reject') as Map<String, dynamic>);

  Future<List<Institution>> listAllInstitutions() async =>
      _items(await _api.get('/admin/institutions')).map(Institution.fromJson).toList();

  /// Kurumu aktifleştirir veya pasifleştirir. Pasif kurum hastalara görünmez.
  Future<Institution> setInstitutionActive(int id, bool isActive) async => Institution.fromJson(
    await _api.patch('/admin/institutions/$id', {'is_active': isActive}) as Map<String, dynamic>,
  );

  /// Kurum yöneticisine yeni geçici şifre atar; şifre yalnızca bu yanıtta döner.
  Future<AdminPasswordReset> resetAdminPassword(int institutionId) async => AdminPasswordReset.fromJson(
    await _api.post('/admin/institutions/$institutionId/reset-admin-password') as Map<String, dynamic>,
  );
}

/// Yönetici şifre sıfırlama sonucu.
class AdminPasswordReset {
  AdminPasswordReset({required this.adminName, required this.adminEmail, required this.temporaryPassword});

  final String adminName;
  final String adminEmail;
  final String temporaryPassword;

  factory AdminPasswordReset.fromJson(Map<String, dynamic> json) => AdminPasswordReset(
    adminName: '${json['admin_first_name']} ${json['admin_last_name']}',
    adminEmail: json['admin_email'] as String,
    temporaryPassword: json['temporary_password'] as String,
  );
}
