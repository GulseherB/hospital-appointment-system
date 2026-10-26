import 'json_model.dart';

class HospitalModel implements JsonModel {
  HospitalModel({
    required this.id,
    required this.name,
    required this.address,
    required this.branches,
  });

  final int id;
  final String name;
  final String address;
  final List<BranchModel> branches;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'branches': branches.map((branch) => branch.toJson()).toList(),
  };
}

class BranchModel implements JsonModel {
  BranchModel({
    required this.id,
    required this.hospitalId,
    required this.name,
    required this.address,
  });

  final int id;
  final int hospitalId;
  final String name;
  final String address;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'hospital_id': hospitalId,
    'name': name,
    'address': address,
  };
}
