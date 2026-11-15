/// Ortak doğrulama kuralları. Asıl kurallar backend'dedir; bunlar kullanıcıya erken geri bildirim içindir.
/// Her fonksiyon geçerliyse `null`, değilse Türkçe hata mesajı döndürür (form doğrulayıcılarıyla uyumlu).
class Validators {
  Validators._();

  static const int minPasswordLength = 8;

  static final RegExp _nationalId = RegExp(r'^[0-9]{11}$');
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phone = RegExp(r'^[0-9+ ]{10,20}$');
  static final RegExp _price = RegExp(r'^[0-9]+(\.[0-9]{1,2})?$');

  static String? requiredText(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName boş bırakılamaz.';
    return null;
  }

  static String? nationalId(String? value) {
    if (value == null || !_nationalId.hasMatch(value.trim())) {
      return 'TC kimlik numarası 11 haneli ve yalnızca rakam olmalıdır.';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || !_email.hasMatch(value.trim())) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || !_phone.hasMatch(value.trim())) {
      return 'Geçerli bir telefon numarası girin.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.runes.length < minPasswordLength) {
      return 'Şifre en az $minPasswordLength karakter olmalıdır.';
    }
    return null;
  }

  static String? price(String? value) {
    if (value == null || !_price.hasMatch(value.trim())) {
      return 'Ücret sayı olmalıdır (ör. 750 veya 750.50).';
    }
    return null;
  }

  static String? durationMin(int? value) {
    if (value == null || value <= 0 || value > 480) {
      return 'Süre 1 ile 480 dakika arasında olmalıdır.';
    }
    return null;
  }
}
