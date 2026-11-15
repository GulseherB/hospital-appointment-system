/// API tarih biçimleri: `YYYY-MM-DDTHH:MM:SS` (Türkiye saati, ek yok), `YYYY-MM-DD`, `HH:MM`.
/// Cihaz saatinin Türkiye saati olduğu varsayılır; asıl zaman kuralları backend'dedir.
class ApiDate {
  ApiDate._();

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// API'den gelen tarih-saati yerel [DateTime] olarak çözer.
  static DateTime parseDateTime(String value) {
    final parsed = DateTime.parse(value);
    if (parsed.isUtc) {
      throw FormatException('Beklenmeyen UTC tarih: $value');
    }
    return parsed;
  }

  static DateTime? parseDateTimeOrNull(Object? value) =>
      value is String && value.isNotEmpty ? parseDateTime(value) : null;

  /// API'ye gönderilecek tarih-saat (`2026-11-20T09:30:00`).
  static String formatDateTime(DateTime value) =>
      '${formatDate(value)}T${_two(value.hour)}:${_two(value.minute)}:${_two(value.second)}';

  /// API'ye gönderilecek tarih (`2026-11-20`).
  static String formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${_two(value.month)}-${_two(value.day)}';

  /// Ekranda gösterilecek tarih-saat (`20.11.2026 09:30`).
  static String display(DateTime value) =>
      '${_two(value.day)}.${_two(value.month)}.${value.year} ${_two(value.hour)}:${_two(value.minute)}';

  /// Ekranda gösterilecek tarih (`20.11.2026`).
  static String displayDate(DateTime value) => '${_two(value.day)}.${_two(value.month)}.${value.year}';

  static const List<String> weekdayNames = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

  /// 1 = Pazartesi ... 7 = Pazar.
  static String weekdayName(int weekday) {
    if (weekday < 1 || weekday > 7) throw RangeError.range(weekday, 1, 7, 'weekday');
    return weekdayNames[weekday - 1];
  }
}
