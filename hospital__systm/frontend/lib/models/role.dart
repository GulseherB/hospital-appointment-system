/// Kullanıcı rolleri. [apiValue] API sözleşmesindeki değerle birebir aynıdır.
enum UserRole {
  superAdmin('super_admin', 'Süper Admin'),
  institutionAdmin('institution_admin', 'Kurum Yöneticisi'),
  doctor('doctor', 'Doktor'),
  patient('patient', 'Hasta');

  const UserRole(this.apiValue, this.label);

  final String apiValue;

  /// Ekranda gösterilen Türkçe ad.
  final String label;

  static UserRole fromApi(String value) {
    for (final role in UserRole.values) {
      if (role.apiValue == value) return role;
    }
    throw FormatException('Bilinmeyen rol: $value');
  }
}

/// Rollerin sahip olabileceği yetkiler. Arayüz, menü ve butonları bunlara göre gösterir.
enum Permission {
  changeOwnPassword,
  bookAppointment,
  viewOwnAppointments,
  cancelOwnAppointment,
  viewNotifications,
  decideAppointments,
  cancelApprovedAppointment,
  manageBranches,
  manageDepartments,
  manageServices,
  manageDoctors,
  viewInstitutionAppointments,
  cancelInstitutionAppointment,
  reviewApplications,
  manageInstitutions,
}

/// Rol menüsündeki bir öğe. Yalnızca veri taşır; simge ve sayfa eşlemesi ekran katmanındadır.
class MenuItem {
  const MenuItem({required this.route, required this.title});

  /// Ekran katmanının sayfa seçmek için kullandığı anahtar (ör. `patient/book`).
  final String route;

  /// Menüde görünen Türkçe başlık.
  final String title;

  @override
  bool operator ==(Object other) => other is MenuItem && other.route == route && other.title == title;

  @override
  int get hashCode => Object.hash(route, title);
}
