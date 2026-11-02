package models

import (
	"errors"
	"time"
)

// ── Roller ───────────────────────────────────────────────────────────────────

type UserRole string

const (
	RoleSuperAdmin      UserRole = "super_admin"
	RolePatient         UserRole = "patient"
	RoleDoctor          UserRole = "doctor"
	RoleHospitalManager UserRole = "hospital_manager"
)

// ── Randevu Durumları ─────────────────────────────────────────────────────────

type AppointmentStatus string

const (
	AppointmentPending   AppointmentStatus = "pending"
	AppointmentConfirmed AppointmentStatus = "confirmed"
	AppointmentRejected  AppointmentStatus = "rejected"
	AppointmentCancelled AppointmentStatus = "cancelled"
	AppointmentCompleted AppointmentStatus = "completed"
	AppointmentNoShow    AppointmentStatus = "no_show"
)

var ErrInvalidAppointmentTransition = errors.New("invalid appointment status transition")

// ChangeStatus geçerli durum geçişlerini uygular.
func (a *Appointment) ChangeStatus(next AppointmentStatus) error {
	switch {
	case a.Status == AppointmentPending && (next == AppointmentConfirmed || next == AppointmentRejected || next == AppointmentCancelled):
	case a.Status == AppointmentConfirmed && (next == AppointmentCancelled || next == AppointmentCompleted || next == AppointmentNoShow):
	default:
		return ErrInvalidAppointmentTransition
	}
	a.Status = next
	return nil
}

// ── Hastane ───────────────────────────────────────────────────────────────────

// Hospital bir hastane veya kliniği temsil eder.
type Hospital struct {
	ID          uint         `gorm:"primaryKey"                                       json:"id"`
	Name        string       `gorm:"size:150;not null"                                json:"name"`
	Description string       `gorm:"size:500"                                         json:"description"`
	Address     string       `gorm:"size:300;not null"                                json:"address"`
	City        string       `gorm:"size:80;index"                                    json:"city"`
	District    string       `gorm:"size:80"                                          json:"district"`
	Phone       string       `gorm:"size:30"                                          json:"phone"`
	Email       string       `gorm:"size:150"                                         json:"email"`
	IsActive    bool         `gorm:"not null;default:true;index"                      json:"is_active"`
	Departments []Department `gorm:"foreignKey:HospitalID;constraint:OnDelete:CASCADE" json:"departments,omitempty"`
	WorkingHours []WorkingHour `gorm:"foreignKey:HospitalID;constraint:OnDelete:CASCADE" json:"working_hours,omitempty"`
	Managers    []User       `gorm:"foreignKey:HospitalID"                            json:"-"`
	CreatedAt   time.Time    `                                                        json:"created_at"`
	UpdatedAt   time.Time    `                                                        json:"updated_at"`
}

// WorkingHour hastanenin bir güne ait çalışma saatlerini tutar.
type WorkingHour struct {
	ID         uint     `gorm:"primaryKey" json:"id"`
	HospitalID uint     `gorm:"not null;index" json:"hospital_id"`
	Hospital   Hospital `gorm:"foreignKey:HospitalID" json:"-"`
	DayOfWeek  int      `gorm:"not null" json:"day_of_week"` // 1=Pazartesi … 7=Pazar
	OpenTime   string   `gorm:"size:5;not null" json:"open_time"`
	CloseTime  string   `gorm:"size:5;not null" json:"close_time"`
}

// ── Bölüm ─────────────────────────────────────────────────────────────────────

// Department bir bölümü veya polikliniği temsil eder.
// Branch katmanı kaldırıldı; bölüm doğrudan hastaneye bağlıdır.
type Department struct {
	ID          uint             `gorm:"primaryKey"                                          json:"id"`
	HospitalID  uint             `gorm:"not null;index"                                      json:"hospital_id"`
	Hospital    Hospital         `gorm:"foreignKey:HospitalID"                               json:"-"`
	Name        string           `gorm:"size:150;not null"                                   json:"name"`
	Description string           `gorm:"size:300"                                            json:"description"`
	Users       []User           `gorm:"foreignKey:DepartmentID"                             json:"-"`
	Services    []MedicalService `gorm:"foreignKey:DepartmentID;constraint:OnDelete:CASCADE" json:"services,omitempty"`
	CreatedAt   time.Time        `                                                           json:"created_at"`
	UpdatedAt   time.Time        `                                                           json:"updated_at"`
}

// ── Kullanıcı ─────────────────────────────────────────────────────────────────

// User tüm kullanıcı rollerini tek tabloda tutar.
type User struct {
	ID                  uint               `gorm:"primaryKey"                                           json:"id"`
	FullName            string             `gorm:"size:150;not null"                                    json:"full_name"`
	Email               string             `gorm:"size:150;not null;uniqueIndex"                        json:"email"`
	PasswordHash        string             `gorm:"size:255;not null"                                    json:"-"`
	Phone               string             `gorm:"size:30;not null"                                     json:"phone"`
	Role                UserRole           `gorm:"size:30;not null;index"                               json:"role"`
	Specialty           string             `gorm:"size:150"                                             json:"specialty,omitempty"`
	HospitalID          *uint              `gorm:"index"                                                json:"hospital_id,omitempty"`
	Hospital            *Hospital          `gorm:"foreignKey:HospitalID"                                json:"-"`
	DepartmentID        *uint              `gorm:"index"                                                json:"department_id,omitempty"`
	Department          *Department        `gorm:"foreignKey:DepartmentID"                              json:"-"`
	Services            []MedicalService   `gorm:"many2many:employee_services;"                         json:"services,omitempty"`
	WorkSchedules       []WorkSchedule     `gorm:"foreignKey:EmployeeID;constraint:OnDelete:CASCADE"    json:"work_schedules,omitempty"`
	TimeOffs            []TimeOff          `gorm:"foreignKey:EmployeeID;constraint:OnDelete:CASCADE"    json:"-"`
	PatientAppointments []Appointment      `gorm:"foreignKey:PatientID"                                 json:"-"`
	DoctorAppointments  []Appointment      `gorm:"foreignKey:DoctorID"                                  json:"-"`
	CreatedAt           time.Time          `                                                            json:"created_at"`
	UpdatedAt           time.Time          `                                                            json:"updated_at"`
}

// ── Sağlık Hizmeti ────────────────────────────────────────────────────────────

// MedicalService bir sağlık hizmetini (muayene, ultrason vb.) temsil eder.
type MedicalService struct {
	ID              uint       `gorm:"primaryKey"                     json:"id"`
	HospitalID      uint       `gorm:"not null;index"                 json:"hospital_id"`
	Hospital        Hospital   `gorm:"foreignKey:HospitalID"          json:"-"`
	DepartmentID    uint       `gorm:"not null;index"                 json:"department_id"`
	Department      Department `gorm:"foreignKey:DepartmentID"        json:"-"`
	Name            string     `gorm:"size:150;not null"              json:"name"`
	Description     string     `gorm:"size:500"                       json:"description"`
	DurationMinutes int        `gorm:"not null"                       json:"duration_minutes"`
	Fee             float64    `gorm:"type:decimal(10,2);not null"    json:"fee"`
	IsActive        bool       `gorm:"not null;default:true;index"    json:"is_active"`
	Doctors         []User     `gorm:"many2many:employee_services;"   json:"doctors,omitempty"`
	CreatedAt       time.Time  `                                      json:"created_at"`
	UpdatedAt       time.Time  `                                      json:"updated_at"`
}

// ── Çalışma Programı ──────────────────────────────────────────────────────────

// WorkSchedule bir çalışanın (doktor) haftalık mesai programını tutar.
// Eski Availability ve EmployeeWorkingHour tablolarının yerini alır.
// Mesai sadece Hastane Yönetimi tarafından tanımlanır; doktorlar değiştiremez.
type WorkSchedule struct {
	ID         uint      `gorm:"primaryKey"     json:"id"`
	EmployeeID uint      `gorm:"not null;index" json:"employee_id"`
	Employee   User      `gorm:"foreignKey:EmployeeID" json:"-"`
	HospitalID uint      `gorm:"not null;index" json:"hospital_id"`
	DayOfWeek  int       `gorm:"not null"       json:"day_of_week"` // 1=Pazartesi … 7=Pazar
	StartTime  string    `gorm:"size:5;not null" json:"start_time"`
	EndTime    string    `gorm:"size:5;not null" json:"end_time"`
	BreakStart string    `gorm:"size:5"         json:"break_start,omitempty"`
	BreakEnd   string    `gorm:"size:5"         json:"break_end,omitempty"`
	CreatedAt  time.Time `                      json:"created_at"`
}

// TimeOff bir çalışanın izin veya tatil dönemini tutar.
type TimeOff struct {
	ID         uint      `gorm:"primaryKey"     json:"id"`
	EmployeeID uint      `gorm:"not null;index" json:"employee_id"`
	Employee   User      `gorm:"foreignKey:EmployeeID" json:"-"`
	StartsAt   time.Time `gorm:"not null"       json:"starts_at"`
	EndsAt     time.Time `gorm:"not null"       json:"ends_at"`
	Reason     string    `gorm:"size:255"       json:"reason,omitempty"`
}

// ── Randevu ───────────────────────────────────────────────────────────────────

// Appointment bir randevu kaydını tutar.
type Appointment struct {
	ID            uint                       `gorm:"primaryKey"                                              json:"id"`
	PatientID     uint                       `gorm:"not null;index"                                          json:"patient_id"`
	Patient       User                       `gorm:"foreignKey:PatientID"                                    json:"patient"`
	HospitalID    uint                       `gorm:"not null;index"                                          json:"hospital_id"`
	Hospital      Hospital                   `gorm:"foreignKey:HospitalID"                                   json:"hospital"`
	DepartmentID  uint                       `gorm:"not null;index"                                          json:"department_id"`
	Department    Department                 `gorm:"foreignKey:DepartmentID"                                 json:"department"`
	DoctorID      uint                       `gorm:"not null;index"                                          json:"doctor_id"`
	Doctor        User                       `gorm:"foreignKey:DoctorID"                                     json:"doctor"`
	ServiceID     uint                       `gorm:"not null;index"                                          json:"service_id"`
	Service       MedicalService             `gorm:"foreignKey:ServiceID"                                    json:"service"`
	StartsAt      time.Time                  `gorm:"not null;index"                                          json:"starts_at"`
	EndsAt        time.Time                  `gorm:"not null"                                                json:"ends_at"`
	Fee           float64                    `gorm:"type:decimal(10,2);not null"                             json:"fee"`
	Status        AppointmentStatus          `gorm:"size:20;not null;index"                                  json:"status"`
	Note          string                     `gorm:"size:500"                                                json:"note,omitempty"`
	StatusHistory []AppointmentStatusHistory `gorm:"foreignKey:AppointmentID;constraint:OnDelete:CASCADE"    json:"status_history,omitempty"`
	CreatedAt     time.Time                  `                                                               json:"created_at"`
	UpdatedAt     time.Time                  `                                                               json:"updated_at"`
}

// AppointmentStatusHistory randevu durum değişikliklerinin tarihçesini tutar.
type AppointmentStatusHistory struct {
	ID            uint              `gorm:"primaryKey"     json:"id"`
	AppointmentID uint              `gorm:"not null;index" json:"appointment_id"`
	Appointment   Appointment       `gorm:"foreignKey:AppointmentID" json:"-"`
	FromStatus    AppointmentStatus `gorm:"size:20;not null" json:"from_status"`
	ToStatus      AppointmentStatus `gorm:"size:20;not null" json:"to_status"`
	ChangedByID   uint              `gorm:"not null;index" json:"changed_by_id"`
	ChangedBy     User              `gorm:"foreignKey:ChangedByID" json:"-"`
	CreatedAt     time.Time         `                      json:"created_at"`
}
