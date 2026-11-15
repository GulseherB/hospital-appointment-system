import '../core/validators.dart';

/// Kurum türü. [apiValue] API sözleşmesindeki değerdir.
enum InstitutionType {
  hospital('hospital', 'Hastane'),
  clinic('clinic', 'Klinik');

  const InstitutionType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static InstitutionType fromApi(String value) => InstitutionType.values.firstWhere(
    (t) => t.apiValue == value,
    orElse: () => throw FormatException('Bilinmeyen kurum türü: $value'),
  );
}

/// Bileşim zinciri: Institution → Branch → Department → Service.
class Institution {
  Institution({
    required this.id,
    required this.name,
    required this.type,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.isActive = true,
  });

  final int id;
  final String name;
  final InstitutionType type;
  final String address;
  final String phone;
  final String email;
  final bool isActive;

  factory Institution.fromJson(Map<String, dynamic> json) => Institution(
    id: json['id'] as int,
    name: json['name'] as String,
    type: InstitutionType.fromApi(json['type'] as String),
    address: (json['address'] as String?) ?? '',
    phone: (json['phone'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    isActive: (json['is_active'] as bool?) ?? true,
  );
}

class Branch {
  Branch({
    required this.id,
    required this.name,
    this.institutionId,
    this.address = '',
    this.phone = '',
    this.isActive = true,
  });

  final int id;
  final int? institutionId;
  final String name;
  final String address;
  final String phone;
  final bool isActive;

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: json['id'] as int,
    institutionId: json['institution_id'] as int?,
    name: json['name'] as String,
    address: (json['address'] as String?) ?? '',
    phone: (json['phone'] as String?) ?? '',
    isActive: (json['is_active'] as bool?) ?? true,
  );
}

class Department {
  Department({required this.id, required this.name, this.branchId, this.isActive = true});

  final int id;
  final int? branchId;
  final String name;
  final bool isActive;

  factory Department.fromJson(Map<String, dynamic> json) => Department(
    id: json['id'] as int,
    branchId: json['branch_id'] as int?,
    name: json['name'] as String,
    isActive: (json['is_active'] as bool?) ?? true,
  );
}

/// Sağlık hizmeti. Kapsülleme: süre 1–480 dakika, ücret negatif olmayan sayı (metin olarak, ör. "750.00").
class Service {
  Service({
    required int id,
    required String name,
    required int durationMin,
    required String price,
    int? departmentId,
    bool isActive = true,
  }) : _id = id,
       _name = name.trim(),
       _durationMin = durationMin,
       _price = price,
       _departmentId = departmentId,
       _isActive = isActive {
    final durationError = Validators.durationMin(durationMin);
    if (durationError != null) throw ArgumentError(durationError);
    final priceError = Validators.price(price);
    if (priceError != null) throw ArgumentError(priceError);
  }

  final int _id;
  final String _name;
  final int _durationMin;
  final String _price;
  final int? _departmentId;
  final bool _isActive;

  int get id => _id;
  String get name => _name;
  int get durationMin => _durationMin;

  /// API'deki ücret metni (ör. "750.00").
  String get price => _price;
  int? get departmentId => _departmentId;
  bool get isActive => _isActive;

  /// Ekranda gösterilen ücret (ör. "750,00 ₺"). Ödeme sistemde yoktur; yalnızca bilgi.
  String get priceLabel => formatPrice(_price);

  factory Service.fromJson(Map<String, dynamic> json) => Service(
    id: json['id'] as int,
    name: json['name'] as String,
    durationMin: json['duration_min'] as int,
    price: json['price'] as String,
    departmentId: json['department_id'] as int?,
    isActive: (json['is_active'] as bool?) ?? true,
  );
}

/// "750.00" → "750,00 ₺".
String formatPrice(String apiPrice) {
  final parts = apiPrice.split('.');
  final decimals = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  return '${parts[0]},$decimals ₺';
}
