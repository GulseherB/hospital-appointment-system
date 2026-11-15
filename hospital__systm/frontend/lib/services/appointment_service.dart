import '../core/date_utils.dart';
import '../models/app_notification.dart';
import '../models/appointment.dart';
import '../models/institution.dart';
import 'api_client.dart';

List<Map<String, dynamic>> _items(dynamic json) =>
    ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();

/// Hasta uç noktaları: kurum/şube/bölüm/hizmet araması, slotlar ve randevular (API sözleşmesi → Hasta).
class PatientService {
  PatientService(this._api);

  final ApiClient _api;

  Future<List<Institution>> institutions() async =>
      _items(await _api.get('/institutions')).map(Institution.fromJson).toList();

  Future<List<Branch>> branches(int institutionId) async =>
      _items(await _api.get('/institutions/$institutionId/branches')).map(Branch.fromJson).toList();

  Future<List<Department>> departments(int branchId) async =>
      _items(await _api.get('/branches/$branchId/departments')).map(Department.fromJson).toList();

  Future<List<Service>> services(int departmentId) async =>
      _items(await _api.get('/services', query: {'department_id': '$departmentId'})).map(Service.fromJson).toList();

  /// Sunucunun ürettiği uygun slotlar. Hasta saat belirlemez; yalnızca bunlardan seçer.
  Future<List<AppointmentSlot>> slots(int serviceId, {int? doctorId, DateTime? dateFrom, DateTime? dateTo}) async =>
      _items(
        await _api.get(
          '/appointment-slots',
          query: {
            'service_id': '$serviceId',
            'doctor_id': doctorId?.toString(),
            'date_from': dateFrom == null ? null : ApiDate.formatDate(dateFrom),
            'date_to': dateTo == null ? null : ApiDate.formatDate(dateTo),
          },
        ),
      ).map(AppointmentSlot.fromJson).toList();

  Future<Appointment> book({required int serviceId, required AppointmentSlot slot}) async => Appointment.fromJson(
    await _api.post('/appointments', {
          'service_id': serviceId,
          'doctor_id': slot.doctorId,
          'start_at': ApiDate.formatDateTime(slot.startAt),
        })
        as Map<String, dynamic>,
  );

  Future<List<Appointment>> myAppointments() async =>
      _items(await _api.get('/my-appointments')).map(Appointment.fromJson).toList();

  Future<Appointment> cancel(int appointmentId) async =>
      Appointment.fromJson(await _api.post('/appointments/$appointmentId/cancel') as Map<String, dynamic>);
}

/// Bildirim listesi ve okunmamış sayısı.
class NotificationPage {
  NotificationPage({required this.items, required this.unreadCount});

  final List<AppNotification> items;
  final int unreadCount;

  factory NotificationPage.fromJson(Map<String, dynamic> json) => NotificationPage(
    items: _items(json).map(AppNotification.fromJson).toList(),
    unreadCount: json['unread_count'] as int,
  );
}

/// Hastanın bildirim paneli uç noktaları.
class NotificationService {
  NotificationService(this._api);

  final ApiClient _api;

  Future<NotificationPage> list({bool unreadOnly = false}) async => NotificationPage.fromJson(
    await _api.get('/my-notifications', query: {'unread': unreadOnly ? 'true' : null}) as Map<String, dynamic>,
  );

  Future<AppNotification> markRead(int id) async =>
      AppNotification.fromJson(await _api.post('/my-notifications/$id/read') as Map<String, dynamic>);

  /// Tümünü okundu işaretler; değişen bildirim sayısını döndürür.
  Future<int> markAllRead() async =>
      ((await _api.post('/my-notifications/read-all')) as Map<String, dynamic>)['updated'] as int;
}

/// Doktor uç noktaları: kendi randevuları, onay, red, iptal.
class DoctorService {
  DoctorService(this._api);

  final ApiClient _api;

  Future<List<Appointment>> appointments({AppointmentStatus? status, DateTime? date}) async => _items(
    await _api.get(
      '/doctor/appointments',
      query: {'status': status?.apiValue, 'date': date == null ? null : ApiDate.formatDate(date)},
    ),
  ).map(Appointment.fromJson).toList();

  Future<Appointment> approve(int id) async => _action('approve', id);

  Future<Appointment> reject(int id) async => _action('reject', id);

  Future<Appointment> cancel(int id) async => _action('cancel', id);

  Future<Appointment> _action(String action, int id) async =>
      Appointment.fromJson(await _api.post('/doctor/appointments/$id/$action') as Map<String, dynamic>);
}
