# Hastane / Klinik Randevu Sistemi

**Ders:** Nesneye Dayalı Programlama Dilleri
**Hazırlayan:** Gülseher Başağa
**Okul No:** Y265012074
**Enstitü:** Fen Bilimleri Enstitüsü
**Anabilim Dalı:** Bilgisayar Mühendisliği Anabilim Dalı
**Program:** Bilgisayar Mühendisliği Pr. (YL) (Tezli)

## Teknolojiler

| Arayüz | Flutter (Dart) | Flutter 3.41.7, Dart 3.11.5 |
| API | Go (REST, JWT) | Go 1.26.2 |
| Veritabanı | MySQL (yerel) | MySQL 8.4 |

## Gerekli programlar

- Go: https://go.dev/dl/
- Flutter: https://docs.flutter.dev/get-started/install
- MySQL Community Server: https://dev.mysql.com/downloads/mysql/

## Kurulum ve çalıştırma

Proje yerel makinede çalışır. İki terminal gerekir: biri backend, biri frontend için.

### 1) Backend (Go + MySQL)

```powershell
cd hospital__systm/backend
```

1. Veritabanını ve uygulama kullanıcısını oluşturun (MySQL root ile, bir kez):
   ```powershell
   mysql -u root -p -e "source scripts/create_db.sql"
   ```
2. Ayar dosyasını oluşturun:
   ```powershell
   Copy-Item .env.example .env
   ```
   `scripts/create_db.sql` içindeki şifreyi değiştirdiyseniz `.env` içindeki `DB_PASSWORD` aynı olmalıdır.
3. Tabloları kurun:
   ```powershell
   go run ./cmd/migrate up
   ```
4. Süper admin ve demo verisini ekleyin:
   ```powershell
   go run ./cmd/seed -demo
   ```
5. API'yi başlatın:
   ```powershell
   go run ./cmd/api
   ```
   Kontrol: http://localhost:8080/api/v1/health

### 2) Frontend (Flutter)

Yeni bir terminalde, backend çalışırken:

```powershell
cd hospital__systm/frontend
flutter pub get
flutter run -d chrome
```

Windows masaüstü uygulaması olarak çalıştırmak için `flutter run -d windows` kullanılabilir.

Backend ve frontend klasörlerinin kendi `README.md` dosyalarında komutlar ve klasör açıklamaları ayrıca vardır.
