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
}
