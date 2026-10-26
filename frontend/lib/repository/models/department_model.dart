import 'json_model.dart';

class DepartmentModel implements JsonModel {
  DepartmentModel({
    required this.id,
    required this.branchId,
    required this.name,
  });

  final int id;
  final int branchId;
  final String name;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'branch_id': branchId,
    'name': name,
  };
}
