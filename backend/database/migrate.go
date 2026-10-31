package database

import (
	"fmt"

	"github.com/GulseherB/hospital-appointment-system/backend/models"
	"gorm.io/gorm"
)

func Migrate(db *gorm.DB) error {
	if err := db.AutoMigrate(
		&models.Hospital{},
		&models.Branch{},
		&models.Department{},
		&models.User{},
		&models.MedicalService{},
		&models.WorkingHour{},
		&models.Availability{},
		&models.Appointment{},
	); err != nil {
		return fmt.Errorf("migrate database: %w", err)
	}
	return nil
}
