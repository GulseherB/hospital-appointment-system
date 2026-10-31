import '../../core/enum/user_role.dart';
import 'json_model.dart';

abstract class UserModel implements JsonModel {
  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
  });

  final int id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;

  String get dashboardTitle;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final role = UserRole.fromApi(json['role'] as String);
    final common = (
      id: (json['id'] as num).toInt(),
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
    );

    return switch (role) {
      UserRole.patient => PatientModel(
        id: common.id,
        fullName: common.fullName,
        email: common.email,
        phone: common.phone,
      ),
      UserRole.doctor => DoctorModel(
        id: common.id,
        fullName: common.fullName,
        email: common.email,
        phone: common.phone,
        specialty: json['specialty'] as String? ?? '',
      ),
      UserRole.healthStaff => HealthStaffModel(
        id: common.id,
        fullName: common.fullName,
        email: common.email,
        phone: common.phone,
        departmentId: (json['department_id'] as num).toInt(),
      ),
      UserRole.hospitalManager => HospitalManagerModel(
        id: common.id,
        fullName: common.fullName,
        email: common.email,
        phone: common.phone,
        organizationId: (json['organization_id'] as num).toInt(),
      ),
    };
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'role': role.apiValue,
  };
}

class PatientModel extends UserModel {
  PatientModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.phone,
  }) : super(role: UserRole.patient);

  @override
  String get dashboardTitle => 'Hasta paneli';
}

class DoctorModel extends UserModel {
  DoctorModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.phone,
    required this.specialty,
  }) : super(role: UserRole.doctor);

  final String specialty;

  @override
  String get dashboardTitle => 'Doktor paneli';

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'specialty': specialty};
}

class HealthStaffModel extends UserModel {
  HealthStaffModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.phone,
    required this.departmentId,
  }) : super(role: UserRole.healthStaff);

  final int departmentId;

  @override
  String get dashboardTitle => 'Sağlık personeli paneli';

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'department_id': departmentId,
  };
}

class HospitalManagerModel extends UserModel {
  HospitalManagerModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.phone,
    required this.organizationId,
  }) : super(role: UserRole.hospitalManager);

  final int organizationId;

  @override
  String get dashboardTitle => 'Yönetici paneli';

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'organization_id': organizationId,
  };
}
