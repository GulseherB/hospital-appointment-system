import 'json_model.dart';

class AvailabilityModel implements JsonModel {
  AvailabilityModel({
    required this.id,
    required this.doctorId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  }) : assert(
         startTime.isBefore(endTime),
         'Availability start must be before end',
       );

  final int id;
  final int doctorId;
  final int dayOfWeek;
  final DateTime startTime;
  final DateTime endTime;

  bool includes(DateTime value) {
    return value.weekday == dayOfWeek &&
        !value.isBefore(startTime) &&
        value.isBefore(endTime);
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'doctor_id': doctorId,
    'day_of_week': dayOfWeek,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
  };
}
