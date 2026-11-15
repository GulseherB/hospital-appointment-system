import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_app/core/date_utils.dart';
import 'package:hospital_app/models/appointment.dart';
import 'package:hospital_app/models/clock_time.dart';
import 'package:hospital_app/models/institution.dart';
import 'package:hospital_app/models/role.dart';

Map<String, dynamic> _appointmentJson(String status, String startAt, String endAt) => {
  'id': 1,
  'status': status,
  'start_at': startAt,
  'end_at': endAt,
  'service_id': 2,
  'service_name': 'Genel Muayene',
  'duration_min': 15,
  'price': '750.00',
  'doctor_id': 3,
  'doctor_name': 'Dr. Ayşe Demir',
  'patient_id': 5,
  'patient_name': 'Ali Örnek',
  'branch_name': 'Merkez',
  'institution_name': 'Demo Sağlık Kliniği',
  'cancelled_by': null,
  'cancelled_at': null,
  'created_at': '2026-11-13T10:00:00',
};

void main() {
  final start = DateTime(2026, 11, 20, 9, 30);

  Appointment build(String status) =>
      Appointment.fromJson(_appointmentJson(status, '2026-11-20T09:30:00', '2026-11-20T09:45:00'));

  group('Appointment.fromJson', () {
    test('alanları sözleşmeye göre okur', () {
      final a = build('pending');
      expect(a.status, AppointmentStatus.pending);
      expect(a.startAt, start);
      expect(a.priceLabel, '750,00 ₺');
      expect(a.cancelledBy, isNull);
      expect(a.createdAt, DateTime(2026, 11, 13, 10));
    });

    test('bitiş başlangıçtan önceyse hata verir', () {
      expect(
        () => Appointment.fromJson(_appointmentJson('pending', '2026-11-20T10:00:00', '2026-11-20T09:00:00')),
        throwsArgumentError,
      );
    });
  });

  group('Cancellable: 2 saat kuralı', () {
    test('tam 2 saat kala iptal edilebilir, 1 dakika sonrası edilemez', () {
      final a = build('approved');
      expect(a.canBeCancelledAt(start.subtract(const Duration(hours: 2))), isTrue);
      expect(a.canBeCancelledAt(start.subtract(const Duration(hours: 1, minutes: 59))), isFalse);
      expect(a.canBeCancelledAt(start.add(const Duration(minutes: 1))), isFalse);
    });

    test('aktif olmayan randevu iptal edilemez', () {
      final now = start.subtract(const Duration(days: 1));
      for (final s in ['rejected', 'cancelled', 'completed']) {
        expect(build(s).canBeCancelledAt(now), isFalse, reason: s);
      }
    });

    test('doktor yalnızca onayladığı randevuyu iptal eder', () {
      final now = start.subtract(const Duration(days: 1));
      expect(build('pending').canBeCancelledBy(UserRole.doctor, now), isFalse);
      expect(build('approved').canBeCancelledBy(UserRole.doctor, now), isTrue);
      expect(build('pending').canBeCancelledBy(UserRole.patient, now), isTrue);
      expect(build('pending').canBeCancelledBy(UserRole.institutionAdmin, now), isTrue);
      expect(build('approved').canBeCancelledBy(UserRole.superAdmin, now), isFalse);
    });
  });

  test('Approvable: yalnızca bekleyen randevuya karar verilir', () {
    expect(build('pending').canBeDecided, isTrue);
    expect(build('approved').canBeDecided, isFalse);
  });

  group('Service ve ClockTime doğrulaması', () {
    test('geçersiz süre ve ücret reddedilir', () {
      expect(() => Service(id: 1, name: 'X', durationMin: 0, price: '10.00'), throwsArgumentError);
      expect(() => Service(id: 1, name: 'X', durationMin: 15, price: '-5'), throwsArgumentError);
      expect(Service(id: 1, name: 'X', durationMin: 15, price: '600.00').priceLabel, '600,00 ₺');
    });

    test('saat aralığı: bitiş başlangıçtan sonra olmalı, çakışma tespit edilir', () {
      expect(() => WeeklyTimeRange(weekday: 1, start: ClockTime(10, 0), end: ClockTime(9, 0)), throwsArgumentError);
      final a = WeeklyTimeRange(weekday: 1, start: ClockTime(9, 0), end: ClockTime(12, 0));
      final b = WeeklyTimeRange(weekday: 1, start: ClockTime(11, 0), end: ClockTime(13, 0));
      final c = WeeklyTimeRange(weekday: 1, start: ClockTime(12, 0), end: ClockTime(13, 0));
      expect(a.overlaps(b), isTrue);
      expect(a.overlaps(c), isFalse);
      expect(ClockTime.parse('09:05:00').toString(), '09:05');
      expect(a.toAvailabilityJson(), {'weekday': 1, 'start_time': '09:00', 'end_time': '12:00'});
    });
  });

  test('ApiDate biçimleri', () {
    expect(ApiDate.formatDateTime(start), '2026-11-20T09:30:00');
    expect(ApiDate.formatDate(start), '2026-11-20');
    expect(ApiDate.display(start), '20.11.2026 09:30');
    expect(ApiDate.weekdayName(1), 'Pazartesi');
    expect(() => ApiDate.parseDateTime('2026-11-20T09:30:00Z'), throwsFormatException);
  });
}
