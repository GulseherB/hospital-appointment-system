/// Onay bekleyebilen kayıtların arayüzü (ör. randevu, kurum başvurusu).
abstract interface class Approvable {
  /// Kayıt şu an onaylanabilir veya reddedilebilir mi?
  bool get canBeDecided;
}

/// İptal edilebilen kayıtların arayüzü (2 saat kuralı).
abstract interface class Cancellable {
  /// İptal için randevuya kalması gereken en az süre.
  static const Duration minNoticeBeforeStart = Duration(hours: 2);

  /// [now] anında iptal edilebilir mi?
  bool canBeCancelledAt(DateTime now);
}
