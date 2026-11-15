// Package domain, db ve API'de ortak kullanılan sabit değerleri tanımlar.
// Değerler migration'daki ENUM tanımlarıyla ve API sözleşmesiyle birebir aynı olmalıdır.
package domain

// Role, kullanıcının sistemdeki rolüdür.
type Role string

const (
	RoleSuperAdmin       Role = "super_admin"
	RoleInstitutionAdmin Role = "institution_admin"
	RoleDoctor           Role = "doctor"
	RolePatient          Role = "patient"
)

// AppointmentStatus, randevunun yaşam döngüsündeki durumudur.
type AppointmentStatus string

const (
	AppointmentPending   AppointmentStatus = "pending"
	AppointmentApproved  AppointmentStatus = "approved"
	AppointmentRejected  AppointmentStatus = "rejected"
	AppointmentCancelled AppointmentStatus = "cancelled"
	AppointmentCompleted AppointmentStatus = "completed"
)

// CancelledBy, bir randevuyu kimin iptal ettiğini gösterir.
type CancelledBy string

const (
	CancelledByPatient CancelledBy = "patient"
	CancelledByDoctor  CancelledBy = "doctor"
	CancelledByAdmin   CancelledBy = "admin"
	CancelledBySystem  CancelledBy = "system"
)

// NotificationType, hastaya düşen bildirimin türüdür.
type NotificationType string

const (
	NotificationApproved          NotificationType = "appointment_approved"
	NotificationRejected          NotificationType = "appointment_rejected"
	NotificationCancelledByDoctor NotificationType = "appointment_cancelled_by_doctor"
	NotificationCancelledByAdmin  NotificationType = "appointment_cancelled_by_admin"
	NotificationCancelledAuto     NotificationType = "appointment_cancelled_auto"
)

// ApplicationStatus, kurum başvurusunun durumudur.
type ApplicationStatus string

const (
	ApplicationPending  ApplicationStatus = "pending"
	ApplicationApproved ApplicationStatus = "approved"
	ApplicationRejected ApplicationStatus = "rejected"
)

// InstitutionType, kurumun türüdür.
type InstitutionType string

const (
	InstitutionHospital InstitutionType = "hospital"
	InstitutionClinic   InstitutionType = "clinic"
)

// MainBranchName, kurum onaylandığında otomatik açılan şubenin (kullanıcıya görünen) adıdır.
const MainBranchName = "Merkez"

// WorkingHours, bir gün için açılış ve kapanış saatidir ("HH:MM:SS" biçiminde).
type WorkingHours struct {
	Weekday  int // 1 = Pazartesi ... 7 = Pazar
	OpensAt  string
	ClosesAt string
}

// DefaultWorkingHours, yeni "Merkez" şubesine atanan saatlerdir: Pazartesi–Cuma 09:00–17:00.
func DefaultWorkingHours() []WorkingHours {
	hours := make([]WorkingHours, 0, 5)
	for day := 1; day <= 5; day++ {
		hours = append(hours, WorkingHours{Weekday: day, OpensAt: "09:00:00", ClosesAt: "17:00:00"})
	}
	return hours
}
