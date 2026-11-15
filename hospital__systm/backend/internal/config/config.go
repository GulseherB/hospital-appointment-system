// Package config, ayarları ortam değişkenlerinden ve varsa .env dosyasından okur.
// Gizli değerler koda yazılmaz.
package config

import (
	"errors"
	"fmt"
	"os"
	"sort"
	"strings"

	"github.com/joho/godotenv"
)

// Config, uygulamanın tüm ayarlarıdır.
type Config struct {
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string

	HTTPAddr  string
	JWTSecret string

	SuperAdminEmail    string
	SuperAdminPassword string
	DemoPassword       string
}

// Load, .env dosyasını (varsa) yükler ve ayarları döndürür.
// Ortamda zaten tanımlı değişkenler .env tarafından ezilmez.
func Load() (Config, error) {
	if err := godotenv.Load(); err != nil && !errors.Is(err, os.ErrNotExist) {
		return Config{}, fmt.Errorf(".env okunamadı: %w", err)
	}
	return Config{
		DBHost:             get("DB_HOST", "127.0.0.1"),
		DBPort:             get("DB_PORT", "3306"),
		DBUser:             get("DB_USER", ""),
		DBPassword:         get("DB_PASSWORD", ""),
		DBName:             get("DB_NAME", "hospital_db"),
		HTTPAddr:           get("HTTP_ADDR", ":8080"),
		JWTSecret:          get("JWT_SECRET", ""),
		SuperAdminEmail:    strings.ToLower(get("SUPER_ADMIN_EMAIL", "")),
		SuperAdminPassword: get("SUPER_ADMIN_PASSWORD", ""),
		DemoPassword:       get("DEMO_PASSWORD", ""),
	}, nil
}

// ValidateDB, db bağlantısı için zorunlu alanları denetler.
func (c Config) ValidateDB() error {
	return required(map[string]string{"DB_USER": c.DBUser, "DB_NAME": c.DBName})
}

// ValidateSeed, seed komutu için zorunlu alanları denetler.
func (c Config) ValidateSeed(demo bool) error {
	fields := map[string]string{
		"SUPER_ADMIN_EMAIL":    c.SuperAdminEmail,
		"SUPER_ADMIN_PASSWORD": c.SuperAdminPassword,
	}
	if demo {
		fields["DEMO_PASSWORD"] = c.DemoPassword
	}
	return required(fields)
}

func get(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && strings.TrimSpace(v) != "" {
		return strings.TrimSpace(v)
	}
	return fallback
}

func required(fields map[string]string) error {
	var missing []string
	for name, v := range fields {
		if v == "" {
			missing = append(missing, name)
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return fmt.Errorf("eksik ayar: %s", strings.Join(missing, ", "))
	}
	return nil
}
