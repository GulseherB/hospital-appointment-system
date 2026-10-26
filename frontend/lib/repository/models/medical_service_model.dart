import 'json_model.dart';

class MedicalServiceModel implements JsonModel {
  MedicalServiceModel({
    required this.id,
    required this.departmentId,
    required this.name,
    required this.durationMinutes,
    required this.fee,
  }) : assert(durationMinutes > 0, 'Service duration must be positive');

  final int id;
  final int departmentId;
  final String name;
  final int durationMinutes;
  final double fee;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'department_id': departmentId,
    'name': name,
    'duration_minutes': durationMinutes,
    'fee': fee,
  };
}
