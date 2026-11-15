import '../core/date_utils.dart';
import '../models/appointment.dart';
import '../models/clock_time.dart';
import '../models/institution.dart';
import '../models/user.dart';
import 'api_client.dart';

List<Map<String, dynamic>> _items(dynamic json) =>
    ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();

/// Oluşturulan doktor ve yalnızca bir kez gösterilecek geçici şifresi.
class CreatedDoctor {
  CreatedDoctor({required this.doctor, required this.temporaryPassword});

  final DoctorRecord doctor;
  final String temporaryPassword;
}

/// Yönetim ekranındaki doktor kaydı: [Doctor] modeli + verdiği hizmetler.
class DoctorRecord {
  DoctorRecord({required this.doctor, required this.phone, required this.serviceIds});

  final Doctor doctor;
  final String phone;
  final List<int> serviceIds;

  factory DoctorRecord.fromJson(Map<String, dynamic> json) => DoctorRecord(
    doctor: Doctor.fromJson(json),
    phone: (json['phone'] as String?) ?? '',
    serviceIds: ((json['service_ids'] as List?) ?? const []).cast<int>(),
  );
}

/// Doktor güncelleme sonucu: bölüm değişince kaldırılan hizmetler ve şube değişince silinen uygunluk.
class DoctorUpdateResult {
  DoctorUpdateResult({required this.doctor, required this.removedServiceIds, required this.availabilityCleared});

  final DoctorRecord doctor;
  final List<int> removedServiceIds;
  final bool availabilityCleared;

  factory DoctorUpdateResult.fromJson(Map<String, dynamic> json) => DoctorUpdateResult(
    doctor: DoctorRecord.fromJson(json),
    removedServiceIds: ((json['removed_service_ids'] as List?) ?? const []).cast<int>(),
    availabilityCleared: (json['availability_cleared'] as bool?) ?? false,
  );
}

/// Kurum yöneticisi uç noktaları (API sözleşmesi → Kurum yönetimi).
class ManageService {
  ManageService(this._api);

  final ApiClient _api;

  // Şubeler
  Future<List<Branch>> listBranches() async => _items(await _api.get('/manage/branches')).map(Branch.fromJson).toList();

  Future<Branch> createBranch({required String name, String address = '', String phone = ''}) async => Branch.fromJson(
    await _api.post('/manage/branches', {'name': name.trim(), 'address': address.trim(), 'phone': phone.trim()})
        as Map<String, dynamic>,
  );

  Future<List<WeeklyTimeRange>> workingHours(int branchId) async => _items(
    await _api.get('/manage/branches/$branchId/working-hours'),
  ).map(WeeklyTimeRange.fromWorkingHoursJson).toList();

  Future<List<WeeklyTimeRange>> setWorkingHours(int branchId, List<WeeklyTimeRange> items) async => _items(
    await _api.put('/manage/branches/$branchId/working-hours', {
      'items': [for (final r in items) r.toWorkingHoursJson()],
    }),
  ).map(WeeklyTimeRange.fromWorkingHoursJson).toList();

  // Bölümler
  Future<List<Department>> listDepartments({int? branchId}) async => _items(
    await _api.get('/manage/departments', query: {'branch_id': branchId?.toString()}),
  ).map(Department.fromJson).toList();

  Future<Department> createDepartment({required int branchId, required String name}) async => Department.fromJson(
    await _api.post('/manage/departments', {'branch_id': branchId, 'name': name.trim()}) as Map<String, dynamic>,
  );

  // Hizmetler
  Future<List<Service>> listServices({int? departmentId}) async => _items(
    await _api.get('/manage/services', query: {'department_id': departmentId?.toString()}),
  ).map(Service.fromJson).toList();

  Future<Service> createService({
    required int departmentId,
    required String name,
    required int durationMin,
    required String price,
  }) async => Service.fromJson(
    await _api.post('/manage/services', {
          'department_id': departmentId,
          'name': name.trim(),
          'duration_min': durationMin,
          'price': price.trim(),
        })
        as Map<String, dynamic>,
  );

  // Doktorlar
  Future<List<DoctorRecord>> listDoctors() async =>
      _items(await _api.get('/manage/doctors')).map(DoctorRecord.fromJson).toList();

  Future<CreatedDoctor> createDoctor({
    required int branchId,
    required int departmentId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String specialty = '',
  }) async {
    final json =
        await _api.post('/manage/doctors', {
              'branch_id': branchId,
              'department_id': departmentId,
              'first_name': firstName.trim(),
              'last_name': lastName.trim(),
              'email': email.trim(),
              'phone': phone.trim(),
              'specialty': specialty.trim(),
            })
            as Map<String, dynamic>;
    return CreatedDoctor(doctor: DoctorRecord.fromJson(json), temporaryPassword: json['temporary_password'] as String);
  }

  Future<DoctorRecord> setDoctorServices(int doctorId, List<int> serviceIds) async => DoctorRecord.fromJson(
    await _api.put('/manage/doctors/$doctorId/services', {'service_ids': serviceIds}) as Map<String, dynamic>,
  );

  Future<List<WeeklyTimeRange>> availability(int doctorId) async => _items(
    await _api.get('/manage/doctors/$doctorId/availability'),
  ).map(WeeklyTimeRange.fromAvailabilityJson).toList();

  Future<List<WeeklyTimeRange>> setAvailability(int doctorId, List<WeeklyTimeRange> items) async => _items(
    await _api.put('/manage/doctors/$doctorId/availability', {
      'items': [for (final r in items) r.toAvailabilityJson()],
    }),
  ).map(WeeklyTimeRange.fromAvailabilityJson).toList();

  // Güncelleme ve pasifleştirme (PUT: tüm alanlar gönderilir)
  Future<Branch> updateBranch(
    int id, {
    required String name,
    required String address,
    required String phone,
    required bool isActive,
  }) async => Branch.fromJson(
    await _api.put('/manage/branches/$id', {
          'name': name.trim(),
          'address': address.trim(),
          'phone': phone.trim(),
          'is_active': isActive,
        })
        as Map<String, dynamic>,
  );

  Future<Department> updateDepartment(int id, {required String name, required bool isActive}) async =>
      Department.fromJson(
        await _api.put('/manage/departments/$id', {'name': name.trim(), 'is_active': isActive}) as Map<String, dynamic>,
      );

  Future<Service> updateService(
    int id, {
    required String name,
    required int durationMin,
    required String price,
    required bool isActive,
  }) async => Service.fromJson(
    await _api.put('/manage/services/$id', {
          'name': name.trim(),
          'duration_min': durationMin,
          'price': price.trim(),
          'is_active': isActive,
        })
        as Map<String, dynamic>,
  );

  Future<DoctorUpdateResult> updateDoctor(
    int id, {
    required int branchId,
    required int departmentId,
    required String firstName,
    required String lastName,
    required String phone,
    required String specialty,
    required bool isActive,
  }) async => DoctorUpdateResult.fromJson(
    await _api.put('/manage/doctors/$id', {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone': phone.trim(),
          'specialty': specialty.trim(),
          'branch_id': branchId,
          'department_id': departmentId,
          'is_active': isActive,
        })
        as Map<String, dynamic>,
  );

  /// Doktora yeni geçici şifre atar; şifre yalnızca bu yanıtta döner.
  Future<CreatedDoctor> resetDoctorPassword(int id) async {
    final json = await _api.post('/manage/doctors/$id/reset-password') as Map<String, dynamic>;
    return CreatedDoctor(doctor: DoctorRecord.fromJson(json), temporaryPassword: json['temporary_password'] as String);
  }

  // Randevular
  Future<List<Appointment>> listAppointments({DateTime? date, int? doctorId, AppointmentStatus? status}) async =>
      _items(
        await _api.get(
          '/manage/appointments',
          query: {
            'date': date == null ? null : ApiDate.formatDate(date),
            'doctor_id': doctorId?.toString(),
            'status': status?.apiValue,
          },
        ),
      ).map(Appointment.fromJson).toList();

  Future<Appointment> cancelAppointment(int id) async =>
      Appointment.fromJson(await _api.post('/manage/appointments/$id/cancel') as Map<String, dynamic>);
}
