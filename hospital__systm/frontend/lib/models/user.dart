import '../core/validators.dart';
import 'role.dart';

/// Tüm kullanıcıların ortak soyut sınıfı (soyutlama).
/// Doğrudan oluşturulamaz; rol farkı [menuItems] ve [permissions] ile gösterilir (çok biçimlilik).
abstract class User {
  User({required int id, required String firstName, required String lastName, required String email})
    : _id = id,
      _firstName = _requireName(firstName, 'Ad'),
      _lastName = _requireName(lastName, 'Soyad'),
      _email = _requireEmail(email) {
    if (id <= 0) throw ArgumentError.value(id, 'id', 'pozitif olmalıdır');
  }

  // Kapsülleme: alanlar private, dışarıya yalnızca okuma açık.
  final int _id;
  final String _firstName;
  final String _lastName;
  final String _email;

  int get id => _id;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get email => _email;
  String get fullName => '$_firstName $_lastName';

  /// Ekranda gösterilen ad (alt sınıflar ünvan ekleyebilir).
  String get displayName => fullName;

  UserRole get role;

  /// Rolün menüsü. Arayüz bu listeye göre menüyü kurar.
  List<MenuItem> menuItems();

  /// Rolün yetkileri. Her rol şifresini değiştirebilir.
  Set<Permission> permissions() => {Permission.changeOwnPassword};

  bool can(Permission permission) => permissions().contains(permission);

  /// Giriş yanıtındaki `user` nesnesinden doğru alt sınıfı üretir.
  factory User.fromJson(Map<String, dynamic> json) {
    final role = UserRole.fromApi(json['role'] as String);
    final id = json['id'] as int;
    final firstName = json['first_name'] as String;
    final lastName = json['last_name'] as String;
    final email = json['email'] as String;
    return switch (role) {
      UserRole.patient => Patient(
        id: id,
        firstName: firstName,
        lastName: lastName,
        email: email,
        nationalId: json['national_id'] as String?,
      ),
      UserRole.doctor => Doctor(id: id, firstName: firstName, lastName: lastName, email: email),
      UserRole.institutionAdmin => InstitutionAdmin(
        id: id,
        firstName: firstName,
        lastName: lastName,
        email: email,
        institutionId: json['institution_id'] as int,
      ),
      UserRole.superAdmin => SuperAdmin(id: id, firstName: firstName, lastName: lastName, email: email),
    };
  }

  static String _requireName(String value, String field) {
    final error = Validators.requiredText(value, field);
    if (error != null) throw ArgumentError(error);
    return value.trim();
  }

  static String _requireEmail(String value) {
    final error = Validators.email(value);
    if (error != null) throw ArgumentError(error);
    return value.trim().toLowerCase();
  }
}

/// Hasta: randevu alır, randevularını ve bildirimlerini görür.
class Patient extends User {
  Patient({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    String? nationalId,
  }) : _nationalId = _checkNationalId(nationalId);

  final String? _nationalId;

  /// TC kimlik numarası; giriş yanıtında gelmeyebilir.
  String? get nationalId => _nationalId;

  @override
  UserRole get role => UserRole.patient;

  @override
  List<MenuItem> menuItems() => const [
    MenuItem(route: 'patient/book', title: 'Randevu Al'),
    MenuItem(route: 'patient/appointments', title: 'Randevularım'),
    MenuItem(route: 'patient/notifications', title: 'Bildirimler'),
  ];

  @override
  Set<Permission> permissions() => {
    ...super.permissions(),
    Permission.bookAppointment,
    Permission.viewOwnAppointments,
    Permission.cancelOwnAppointment,
    Permission.viewNotifications,
  };

  static String? _checkNationalId(String? value) {
    if (value == null) return null;
    final error = Validators.nationalId(value);
    if (error != null) throw ArgumentError(error);
    return value;
  }
}

/// Personelin ortak soyut sınıfı (çok seviyeli kalıtım: User → Staff → Doctor ...).
/// Personel hesapları yönetici tarafından açılır ve geçici şifre alabilir.
abstract class Staff extends User {
  Staff({required super.id, required super.firstName, required super.lastName, required super.email});

  /// Ünvan (ör. "Dr."); boşsa gösterilmez.
  String get title;

  @override
  String get displayName => title.isEmpty ? fullName : '$title $fullName';
}

/// Doktor: kendi randevularını onaylar, reddeder veya iptal eder.
class Doctor extends Staff {
  Doctor({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    int? branchId,
    int? departmentId,
    String specialty = '',
    bool isActive = true,
  }) : _branchId = branchId,
       _departmentId = departmentId,
       _specialty = specialty.trim(),
       _isActive = isActive;

  final int? _branchId;
  final int? _departmentId;
  final String _specialty;
  final bool _isActive;

  int? get branchId => _branchId;
  int? get departmentId => _departmentId;
  String get specialty => _specialty;
  bool get isActive => _isActive;

  @override
  String get title => 'Dr.';

  @override
  UserRole get role => UserRole.doctor;

  @override
  List<MenuItem> menuItems() => const [
    MenuItem(route: 'doctor/pending', title: 'Bekleyen Randevular'),
    MenuItem(route: 'doctor/appointments', title: 'Tüm Randevularım'),
  ];

  @override
  Set<Permission> permissions() => {
    ...super.permissions(),
    Permission.decideAppointments,
    Permission.cancelApprovedAppointment,
  };

  /// Yönetim listesindeki doktor kaydından üretir.
  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
    id: json['id'] as int,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
    email: json['email'] as String,
    branchId: json['branch_id'] as int?,
    departmentId: json['department_id'] as int?,
    specialty: (json['specialty'] as String?) ?? '',
    isActive: (json['is_active'] as bool?) ?? true,
  );
}

/// Kurum yöneticisi: yalnızca kendi kurumunu yönetir.
class InstitutionAdmin extends Staff {
  InstitutionAdmin({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    required int institutionId,
  }) : _institutionId = institutionId {
    if (institutionId <= 0) {
      throw ArgumentError.value(institutionId, 'institutionId', 'pozitif olmalıdır');
    }
  }

  final int _institutionId;

  int get institutionId => _institutionId;

  @override
  String get title => '';

  @override
  UserRole get role => UserRole.institutionAdmin;

  @override
  List<MenuItem> menuItems() => const [
    MenuItem(route: 'admin/branches', title: 'Şubeler'),
    MenuItem(route: 'admin/departments', title: 'Bölümler'),
    MenuItem(route: 'admin/services', title: 'Hizmetler'),
    MenuItem(route: 'admin/doctors', title: 'Doktorlar'),
    MenuItem(route: 'admin/appointments', title: 'Randevular'),
  ];

  @override
  Set<Permission> permissions() => {
    ...super.permissions(),
    Permission.manageBranches,
    Permission.manageDepartments,
    Permission.manageServices,
    Permission.manageDoctors,
    Permission.viewInstitutionAppointments,
    Permission.cancelInstitutionAppointment,
  };
}

/// Süper admin: kurum başvurularını onaylar ve kurumları yönetir.
class SuperAdmin extends Staff {
  SuperAdmin({required super.id, required super.firstName, required super.lastName, required super.email});

  @override
  String get title => '';

  @override
  UserRole get role => UserRole.superAdmin;

  @override
  List<MenuItem> menuItems() => const [
    MenuItem(route: 'super/applications', title: 'Kurum Başvuruları'),
    MenuItem(route: 'super/institutions', title: 'Kurumlar'),
  ];

  @override
  Set<Permission> permissions() => {
    ...super.permissions(),
    Permission.reviewApplications,
    Permission.manageInstitutions,
  };
}
