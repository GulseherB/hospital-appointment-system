/// Gün içindeki saat (dakika hassasiyetinde). API biçimi `HH:MM`; `HH:MM:SS` de kabul edilir.
/// Arayüz paketine bağımlı olmamak için Flutter'ın TimeOfDay sınıfı yerine kullanılır.
class ClockTime implements Comparable<ClockTime> {
  ClockTime(int hour, int minute) : _hour = hour, _minute = minute {
    if (hour < 0 || hour > 23) throw RangeError.range(hour, 0, 23, 'hour');
    if (minute < 0 || minute > 59) throw RangeError.range(minute, 0, 59, 'minute');
  }

  factory ClockTime.parse(String value) {
    final parts = value.split(':');
    if (parts.length < 2 || parts.length > 3) {
      throw FormatException('Geçersiz saat: $value');
    }
    return ClockTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  final int _hour;
  final int _minute;

  int get hour => _hour;
  int get minute => _minute;
  int get minutesOfDay => _hour * 60 + _minute;

  bool isBefore(ClockTime other) => compareTo(other) < 0;

  @override
  int compareTo(ClockTime other) => minutesOfDay.compareTo(other.minutesOfDay);

  /// API ve ekran biçimi: `09:30`.
  @override
  String toString() => '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) => other is ClockTime && other.minutesOfDay == minutesOfDay;

  @override
  int get hashCode => minutesOfDay.hashCode;
}

/// Haftanın bir günü için saat aralığı (şube çalışma saati veya doktor uygunluğu).
/// Kapsülleme: bitiş başlangıçtan sonra olmalıdır.
class WeeklyTimeRange {
  WeeklyTimeRange({required int weekday, required ClockTime start, required ClockTime end})
    : _weekday = weekday,
      _start = start,
      _end = end {
    if (weekday < 1 || weekday > 7) throw RangeError.range(weekday, 1, 7, 'weekday');
    if (!start.isBefore(end)) {
      throw ArgumentError('Bitiş saati başlangıç saatinden sonra olmalıdır.');
    }
  }

  final int _weekday;
  final ClockTime _start;
  final ClockTime _end;

  /// 1 = Pazartesi ... 7 = Pazar.
  int get weekday => _weekday;
  ClockTime get start => _start;
  ClockTime get end => _end;

  bool overlaps(WeeklyTimeRange other) =>
      other.weekday == weekday && start.isBefore(other.end) && other.start.isBefore(end);

  /// `working-hours` uç noktası biçimi.
  factory WeeklyTimeRange.fromWorkingHoursJson(Map<String, dynamic> json) => WeeklyTimeRange(
    weekday: json['weekday'] as int,
    start: ClockTime.parse(json['opens_at'] as String),
    end: ClockTime.parse(json['closes_at'] as String),
  );

  Map<String, dynamic> toWorkingHoursJson() => {'weekday': weekday, 'opens_at': '$start', 'closes_at': '$end'};

  /// `availability` uç noktası biçimi.
  factory WeeklyTimeRange.fromAvailabilityJson(Map<String, dynamic> json) => WeeklyTimeRange(
    weekday: json['weekday'] as int,
    start: ClockTime.parse(json['start_time'] as String),
    end: ClockTime.parse(json['end_time'] as String),
  );

  Map<String, dynamic> toAvailabilityJson() => {'weekday': weekday, 'start_time': '$start', 'end_time': '$end'};
}
