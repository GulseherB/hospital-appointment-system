-- Veritabanını ve uygulama kullanıcısını oluşturur. MySQL root hesabıyla BİR KEZ çalıştırılır:
--   mysql -u root -p -e "source scripts/create_db.sql"
-- Şifre yalnızca örnektir; değiştirirseniz .env içindeki DB_PASSWORD'u da aynı yapın.

-- Önceki Türkçe adlı deneme kurulumunu kaldırır (yalnızca B1 sırasında oluşturulmuştu, veri içermez).
DROP DATABASE IF EXISTS randevu_sistemi;
DROP USER IF EXISTS 'hastane_app'@'localhost';
DROP USER IF EXISTS 'hastane_app'@'127.0.0.1';

CREATE DATABASE IF NOT EXISTS hospital_db
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_as_ci;

CREATE USER IF NOT EXISTS 'hospital_app'@'localhost' IDENTIFIED BY 'Example_Pass_123';
CREATE USER IF NOT EXISTS 'hospital_app'@'127.0.0.1' IDENTIFIED BY 'Example_Pass_123';

GRANT ALL PRIVILEGES ON hospital_db.* TO 'hospital_app'@'localhost';
GRANT ALL PRIVILEGES ON hospital_db.* TO 'hospital_app'@'127.0.0.1';
FLUSH PRIVILEGES;
