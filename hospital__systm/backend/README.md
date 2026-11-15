# Backend (Go + MySQL)

Komutlar `hospital__systm/backend` klasöründe çalıştırılır.

## İlk kurulum

1. Veritabanını (`hospital_db`) ve uygulama kullanıcısını (`hospital_app`) oluşturun (MySQL root ile, bir kez):
   `mysql -u root -p -e "source scripts/create_db.sql"` (PowerShell'de de çalışır)
2. `.env.example` dosyasını `.env` olarak kopyalayın ve gerekirse değerleri değiştirin.
3. Şemayı kurun: `go run ./cmd/migrate up`
4. Süper admin ve demo verisini ekleyin: `go run ./cmd/seed -demo`
5. API'yi başlatın: `go run ./cmd/api` → `http://localhost:8080/api/v1` (kontrol: `/api/v1/health`)

## Demo hesapları

Şifre: `.env` içindeki `DEMO_PASSWORD`. Süper admin: `SUPER_ADMIN_EMAIL` / `SUPER_ADMIN_PASSWORD`.

| Rol | E-posta |
|---|---|
| Kurum yöneticisi | `admin@demo.local` |
| Doktor (Dahiliye) | `doctor1@demo.local` |
| Doktor (Radyoloji) | `doctor2@demo.local` |
| Hasta | `patient@demo.local` |

## Diğer komutlar

| Komut | Açıklama |
|---|---|
| `go run ./cmd/migrate version` | Uygulanan migration sürümü |
| `go run ./cmd/migrate down -confirm` | Tüm tabloları siler (geri alınamaz) |
| `go test ./...` | Testler |
| `go vet ./...` | Statik denetim |

## Klasörler

| Klasör | İçerik |
|---|---|
| `cmd/api` | REST sunucusu |
| `cmd/migrate` | golang-migrate ile gömülü migration'ları çalıştırır |
| `internal/httpapi` | Uç noktalar, ara katmanlar (CORS, kimlik, rol), JSON yanıt/hata |
| `internal/service` | İş kuralları |
| `internal/repository` | SQL erişimi (Repository kalıbı) |
| `internal/auth` | JWT üretimi ve doğrulaması |
| `internal/apperr` | Sözleşmedeki hata kodları |
| `internal/validate` | İstek alanı doğrulama |
| `cmd/seed` | Süper admin ve demo verisi |
| `migrations` | Sıralı SQL migration dosyaları |
| `scripts` | Tek seferlik db kurulum betiği |
| `internal/domain` | Rol, durum, bildirim türü gibi ortak sabitler |
| `internal/config` | `.env` ve ortam değişkenleri |
| `internal/security` | Şifre özeti (bcrypt) ve geçici şifre üretimi |
| `internal/db` | MySQL bağlantısı (Türkiye saati) |
| `internal/clock` | Tek saat dilimi (Europe/Istanbul) |
