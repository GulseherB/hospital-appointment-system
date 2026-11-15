package service

import (
	"time"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/domain"
	"hospital/backend/internal/repository"
)

// MinCancelNotice, randevuya en az bu kadar süre kala iptal edilebilir (hasta, doktor ve yönetici için).
const MinCancelNotice = 2 * time.Hour

// ApprovalDeadline, bekleyen randevu başlangıca bu süreden az kalınca otomatik iptal edilir.
const ApprovalDeadline = 12 * time.Hour

// CancelPolicy, iptal kuralını tanımlar (Strategy kalıbı). Her rol kendi kuralını uygular;
// iptal işlemi (kilit, durum güncelleme, bildirim) tek bir yerde ve politikadan bağımsız yürür.
type CancelPolicy interface {
	// Actor, randevuya yazılacak cancelled_by değeridir.
	Actor() domain.CancelledBy
	// Check, randevunun bu politika ile şimdi iptal edilip edilemeyeceğini denetler.
	Check(a repository.Appointment, now time.Time) error
	// Notification, hastaya bildirim üretilecekse türünü döndürür.
	Notification() (domain.NotificationType, bool)
}

func isActive(s domain.AppointmentStatus) bool {
	return s == domain.AppointmentPending || s == domain.AppointmentApproved
}

// checkNotice, ortak 2 saat kuralıdır.
func checkNotice(a repository.Appointment, now time.Time) error {
	if a.StartAt.Sub(now) < MinCancelNotice {
		return apperr.BusinessRule("Randevuya 2 saatten az kaldığı için iptal edilemez.")
	}
	return nil
}

// PatientCancelPolicy: hasta kendi aktif randevusunu iptal eder; bildirim üretilmez.
type PatientCancelPolicy struct{}

func (PatientCancelPolicy) Actor() domain.CancelledBy { return domain.CancelledByPatient }

func (PatientCancelPolicy) Check(a repository.Appointment, now time.Time) error {
	if !isActive(a.Status) {
		return apperr.BusinessRule("Yalnızca bekleyen veya onaylanmış randevu iptal edilebilir.")
	}
	return checkNotice(a, now)
}

func (PatientCancelPolicy) Notification() (domain.NotificationType, bool) { return "", false }

// DoctorCancelPolicy: doktor yalnızca onayladığı randevuyu iptal eder.
type DoctorCancelPolicy struct{}

func (DoctorCancelPolicy) Actor() domain.CancelledBy { return domain.CancelledByDoctor }

func (DoctorCancelPolicy) Check(a repository.Appointment, now time.Time) error {
	if a.Status != domain.AppointmentApproved {
		return apperr.BusinessRule("Doktor yalnızca onaylanmış randevuyu iptal edebilir; bekleyen randevuyu reddedebilirsiniz.")
	}
	return checkNotice(a, now)
}

func (DoctorCancelPolicy) Notification() (domain.NotificationType, bool) {
	return domain.NotificationCancelledByDoctor, true
}

// AdminCancelPolicy: kurum yöneticisi kurumundaki herhangi bir aktif randevuyu iptal eder.
type AdminCancelPolicy struct{}

func (AdminCancelPolicy) Actor() domain.CancelledBy { return domain.CancelledByAdmin }

func (AdminCancelPolicy) Check(a repository.Appointment, now time.Time) error {
	if !isActive(a.Status) {
		return apperr.BusinessRule("Yalnızca bekleyen veya onaylanmış randevu iptal edilebilir.")
	}
	return checkNotice(a, now)
}

func (AdminCancelPolicy) Notification() (domain.NotificationType, bool) {
	return domain.NotificationCancelledByAdmin, true
}

// SystemCancelPolicy: zamanlanmış iş, başlangıcına 12 saatten az kalan bekleyen randevuyu iptal eder.
type SystemCancelPolicy struct{}

func (SystemCancelPolicy) Actor() domain.CancelledBy { return domain.CancelledBySystem }

func (SystemCancelPolicy) Check(a repository.Appointment, now time.Time) error {
	if a.Status != domain.AppointmentPending || a.StartAt.Sub(now) >= ApprovalDeadline {
		return apperr.BusinessRule("Otomatik iptal koşulu sağlanmıyor.")
	}
	return nil
}

func (SystemCancelPolicy) Notification() (domain.NotificationType, bool) {
	return domain.NotificationCancelledAuto, true
}

// Derleme anında tüm politikaların arayüzü uyguladığı denetlenir.
var (
	_ CancelPolicy = PatientCancelPolicy{}
	_ CancelPolicy = DoctorCancelPolicy{}
	_ CancelPolicy = AdminCancelPolicy{}
	_ CancelPolicy = SystemCancelPolicy{}
)
