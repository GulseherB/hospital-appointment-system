package database

import (
	"fmt"

	"github.com/GulseherB/hospital-appointment-system/backend/models"
	"gorm.io/gorm"
)

func Migrate(db *gorm.DB) error {
	if err := db.AutoMigrate(
		&models.Hospital{},
		&models.WorkingHour{},
		&models.Department{},
		&models.User{},
		&models.MedicalService{},
		&models.WorkSchedule{},
		&models.TimeOff{},
		&models.Appointment{},
		&models.AppointmentStatusHistory{},
	); err != nil {
		return fmt.Errorf("migrate database: %w", err)
	}
	return nil
}
