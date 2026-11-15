# Frontend (Flutter)

Komutlar `hospital__systm/frontend` klasöründe çalıştırılır. Önce backend çalışıyor olmalıdır (`hospital__systm/backend` → `go run ./cmd/api`).

| Komut | Açıklama |
|---|---|
| `flutter run -d chrome` | Tarayıcıda çalıştırır |
| `flutter run -d windows` | Windows masaüstünde çalıştırır |
| `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api/v1` | Farklı API adresiyle |
| `flutter analyze` | Statik denetim |
| `flutter test` | Testler |

## Klasörler

| Klasör | İçerik |
|---|---|
| `lib/models` | Veri ve kural sınıfları (Widget ve ağ çağrısı yok): `User` hiyerarşisi, randevu, kurum, bildirim |
| `lib/services` | API istemcisi ve uç nokta servisleri, token saklama |
| `lib/state` | Oturum durumu (`SessionController`) |
| `lib/screens` | Ekranlar |
| `lib/widgets` | Ortak arayüz parçaları |
| `lib/core` | Ayarlar, doğrulayıcılar, tarih biçimleri |
