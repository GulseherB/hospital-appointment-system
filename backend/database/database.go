package database

import (
	"fmt"
	"strings"

	"github.com/GulseherB/hospital-appointment-system/backend/config"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func Connect(configuration config.Config) (*gorm.DB, error) {
	serverDSN := fmt.Sprintf(
		"%s:%s@tcp(%s:%s)/?charset=utf8mb4&parseTime=True&loc=Local",
		configuration.DBUser,
		configuration.DBPassword,
		configuration.DBHost,
		configuration.DBPort,
	)

	serverDB, err := gorm.Open(mysql.Open(serverDSN), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("connect to MySQL server: %w", err)
	}

	sqlServerDB, err := serverDB.DB()
	if err != nil {
		return nil, fmt.Errorf("get MySQL server handle: %w", err)
	}
	defer sqlServerDB.Close()

	if err := serverDB.Exec(
		fmt.Sprintf(
			"CREATE DATABASE IF NOT EXISTS `%s` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
			escapeIdentifier(configuration.DBName),
		),
	).Error; err != nil {
		return nil, fmt.Errorf("create database %q: %w", configuration.DBName, err)
	}

	dsn := fmt.Sprintf(
		"%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		configuration.DBUser,
		configuration.DBPassword,
		configuration.DBHost,
		configuration.DBPort,
		configuration.DBName,
	)

	return gorm.Open(mysql.Open(dsn), &gorm.Config{})
}

func escapeIdentifier(identifier string) string {
	return strings.ReplaceAll(identifier, "`", "``")
}
