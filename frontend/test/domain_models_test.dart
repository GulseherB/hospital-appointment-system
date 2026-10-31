import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/enum/appointment_status.dart';
import 'package:frontend/repository/models/appointment_model.dart';
import 'package:frontend/repository/models/availability_model.dart';
import 'package:frontend/repository/models/user_model.dart';

void main() {
  group('UserModel polymorphism', () {
    test('creates the correct subtype from its role', () {
      final user = UserModel.fromJson({
        'id': 1,
        'full_name': 'Dr. Ayşe Kaya',
        'email': 'ayse@example.com',
        'phone': '5550000000',
        'role': 'doctor',
        'specialty': 'Kardiyoloji',
      });

      expect(user, isA<DoctorModel>());
      expect(user.dashboardTitle, 'Doktor paneli');
    });
  });

  group('AppointmentModel state transitions', () {
    late AppointmentModel appointment;

    setUp(() {
      appointment = AppointmentModel(
        id: 1,
        patientId: 10,
        doctorId: 20,
        serviceId: 30,
        startsAt: DateTime(2026, 11, 2, 10),
        endsAt: DateTime(2026, 11, 2, 10, 30),
        fee: 500,
      );
    });

    test('allows only valid transitions', () {
      appointment.confirm();
      appointment.complete();

      expect(appointment.status, AppointmentStatus.completed);
      expect(appointment.cancel, throwsStateError);
    });

    test('detects an overlapping interval', () {
      expect(
        appointment.overlaps(
          DateTime(2026, 11, 2, 10, 15),
          DateTime(2026, 11, 2, 10, 45),
        ),
        isTrue,
      );
    });
  });

  test('availability compares the time of day', () {
    final availability = AvailabilityModel(
      id: 1,
      doctorId: 20,
      dayOfWeek: DateTime.monday,
      startTime: DateTime(2026, 1, 1, 9),
      endTime: DateTime(2026, 1, 1, 17),
    );

    expect(availability.includes(DateTime(2030, 4, 8, 12)), isTrue);
    expect(availability.includes(DateTime(2030, 4, 9, 12)), isFalse);
  });
}
