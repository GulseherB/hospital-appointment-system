package models

import "time"

type UserRole string

const (
	RolePatient         UserRole = "patient"
	RoleDoctor          UserRole = "doctor"
	RoleHealthStaff     UserRole = "health_staff"
	RoleHospitalManager UserRole = "hospital_manager"
)

type AppointmentStatus string

const (
	AppointmentPending   AppointmentStatus = "pending"
	AppointmentConfirmed AppointmentStatus = "confirmed"
	AppointmentCancelled AppointmentStatus = "cancelled"
	AppointmentCompleted AppointmentStatus = "completed"
)

type Hospital struct {
	ID           uint          `gorm:"primaryKey"`
	Name         string        `gorm:"size:150;not null"`
	Address      string        `gorm:"size:300;not null"`
	Branches     []Branch      `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE;"`
	WorkingHours []WorkingHour `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE;"`
	Managers     []User        `gorm:"foreignKey:HospitalID"`
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

type Branch struct {
	ID          uint         `gorm:"primaryKey"`
	HospitalID  uint         `gorm:"not null;index"`
	Hospital    Hospital     `gorm:"foreignKey:HospitalID"`
	Name        string       `gorm:"size:150;not null"`
	Address     string       `gorm:"size:300;not null"`
	Departments []Department `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE;"`
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type Department struct {
	ID        uint             `gorm:"primaryKey"`
	BranchID  uint             `gorm:"not null;index"`
	Branch    Branch           `gorm:"foreignKey:BranchID"`
	Name      string           `gorm:"size:150;not null"`
	Users     []User           `gorm:"foreignKey:DepartmentID"`
	Services  []MedicalService `gorm:"constraint:OnUpdate:CASCADE,OnDelete:CASCADE;"`
	CreatedAt time.Time
	UpdatedAt time.Time
}

type User struct {
	ID                  uint             `gorm:"primaryKey"`
	FullName            string           `gorm:"size:150;not null"`
	Email               string           `gorm:"size:150;not null;uniqueIndex"`
	PasswordHash        string           `gorm:"size:255;not null"`
	Phone               string           `gorm:"size:30;not null"`
	Role                UserRole         `gorm:"size:30;not null;index"`
	Specialty           string           `gorm:"size:150"`
	HospitalID          *uint            `gorm:"index"`
	Hospital            *Hospital        `gorm:"foreignKey:HospitalID"`
	DepartmentID        *uint            `gorm:"index"`
	Department          *Department      `gorm:"foreignKey:DepartmentID"`
	Services            []MedicalService `gorm:"many2many:doctor_services;"`
	Availabilities      []Availability   `gorm:"foreignKey:DoctorID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE;"`
	PatientAppointments []Appointment    `gorm:"foreignKey:PatientID"`
	DoctorAppointments  []Appointment    `gorm:"foreignKey:DoctorID"`
	CreatedAt           time.Time
	UpdatedAt           time.Time
}

type MedicalService struct {
	ID              uint `gorm:"primaryKey"`
	DepartmentID    uint `gorm:"not null;index"`
	Department      Department
	Name            string  `gorm:"size:150;not null"`
	DurationMinutes int     `gorm:"not null"`
	Fee             float64 `gorm:"type:decimal(10,2);not null"`
	Doctors         []User  `gorm:"many2many:doctor_services;"`
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

type WorkingHour struct {
	ID         uint     `gorm:"primaryKey"`
	HospitalID uint     `gorm:"not null;index"`
	Hospital   Hospital `gorm:"foreignKey:HospitalID"`
	DayOfWeek  int      `gorm:"not null"`
	OpenTime   string   `gorm:"size:5;not null"`
	CloseTime  string   `gorm:"size:5;not null"`
}

type Availability struct {
	ID        uint   `gorm:"primaryKey"`
	DoctorID  uint   `gorm:"not null;index"`
	Doctor    User   `gorm:"foreignKey:DoctorID"`
	DayOfWeek int    `gorm:"not null"`
	StartTime string `gorm:"size:5;not null"`
	EndTime   string `gorm:"size:5;not null"`
}

type Appointment struct {
	ID        uint              `gorm:"primaryKey"`
	PatientID uint              `gorm:"not null;index"`
	Patient   User              `gorm:"foreignKey:PatientID"`
	DoctorID  uint              `gorm:"not null;index"`
	Doctor    User              `gorm:"foreignKey:DoctorID"`
	ServiceID uint              `gorm:"not null;index"`
	Service   MedicalService    `gorm:"foreignKey:ServiceID"`
	StartsAt  time.Time         `gorm:"not null;index"`
	EndsAt    time.Time         `gorm:"not null"`
	Fee       float64           `gorm:"type:decimal(10,2);not null"`
	Status    AppointmentStatus `gorm:"size:20;not null;index"`
	CreatedAt time.Time
	UpdatedAt time.Time
}
