package config

import (
	"fmt"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	AppPort            string
	JWTSecret          string
	SuperAdminEmail    string
	SuperAdminPassword string
	DBHost             string
	DBPort             string
	DBUser             string
	DBPassword         string
	DBName             string
}

func Load() (Config, error) {
	_ = godotenv.Load()

	config := Config{
		AppPort:            valueOrDefault("APP_PORT", "8080"),
		JWTSecret:          os.Getenv("JWT_SECRET"),
		SuperAdminEmail:    os.Getenv("SUPER_ADMIN_EMAIL"),
		SuperAdminPassword: os.Getenv("SUPER_ADMIN_PASSWORD"),
		DBHost:             os.Getenv("DB_HOST"),
		DBPort:             os.Getenv("DB_PORT"),
		DBUser:             os.Getenv("DB_USER"),
		DBPassword:         os.Getenv("DB_PASSWORD"),
		DBName:             os.Getenv("DB_NAME"),
	}

	if config.DBHost == "" || config.DBPort == "" || config.DBUser == "" || config.DBName == "" {
		return Config{}, fmt.Errorf("DB_HOST, DB_PORT, DB_USER and DB_NAME must be set")
	}
	if len(config.JWTSecret) < 32 {
		return Config{}, fmt.Errorf("JWT_SECRET must be at least 32 characters")
	}

	return config, nil
}

func valueOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
