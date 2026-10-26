import '../../core/enum/appointment_status.dart';
import 'json_model.dart';

class AppointmentModel implements JsonModel {
  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.serviceId,
    required this.startsAt,
    required this.endsAt,
    required this.fee,
    this.status = AppointmentStatus.pending,
  }) : assert(endsAt.isAfter(startsAt), 'Appointment end must be after start');

  final int id;
  final int patientId;
  final int doctorId;
  final int serviceId;
  final DateTime startsAt;
  final DateTime endsAt;
  final double fee;
  AppointmentStatus status;

  void confirm() {
    _ensureChangeable();
    status = AppointmentStatus.confirmed;
  }

  void cancel() {
    if (status == AppointmentStatus.completed) {
      throw StateError('A completed appointment cannot be cancelled');
    }
    status = AppointmentStatus.cancelled;
  }

  void complete() {
    if (status != AppointmentStatus.confirmed) {
      throw StateError('Only confirmed appointments can be completed');
    }
    status = AppointmentStatus.completed;
  }

  bool overlaps(DateTime start, DateTime end) {
    return start.isBefore(endsAt) && end.isAfter(startsAt);
  }

  void _ensureChangeable() {
    if (status == AppointmentStatus.cancelled ||
        status == AppointmentStatus.completed) {
      throw StateError('This appointment cannot be changed');
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_id': patientId,
    'doctor_id': doctorId,
    'service_id': serviceId,
    'starts_at': startsAt.toIso8601String(),
    'ends_at': endsAt.toIso8601String(),
    'fee': fee,
    'status': status.apiValue,
  };
}
