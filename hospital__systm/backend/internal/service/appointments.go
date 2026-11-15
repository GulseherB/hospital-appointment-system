package service

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"slices"
	"time"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/clock"
	"hospital/backend/internal/domain"
	"hospital/backend/internal/repository"
)

// AppointmentService, hasta araması, slot üretimi, randevu yaşam döngüsü, bildirimler ve zamanlanmış işi yürütür.
type AppointmentService struct {
	db  *sql.DB
	now func() time.Time
}

// NewAppointmentService, servisi oluşturur.
func NewAppointmentService(db *sql.DB, now func() time.Time) *AppointmentService {
	return &AppointmentService{db: db, now: now}
}

// ---- Yanıt nesneleri ----

// AppointmentDTO, randevu yanıtı.
type AppointmentDTO struct {
	ID              int64                    `json:"id"`
	Status          domain.AppointmentStatus `json:"status"`
	StartAt         clock.DateTime           `json:"start_at"`
	EndAt           clock.DateTime           `json:"end_at"`
	ServiceID       int64                    `json:"service_id"`
	ServiceName     string                   `json:"service_name"`
	DurationMin     int                      `json:"duration_min"`
	Price           string                   `json:"price"`
	DoctorID        int64                    `json:"doctor_id"`
	DoctorName      string                   `json:"doctor_name"`
	PatientID       int64                    `json:"patient_id"`
	PatientName     string                   `json:"patient_name"`
	BranchName      string                   `json:"branch_name"`
	InstitutionName string                   `json:"institution_name"`
	CancelledBy     *domain.CancelledBy      `json:"cancelled_by"`
	CancelledAt     *clock.DateTime          `json:"cancelled_at"`
	CreatedAt       clock.DateTime           `json:"created_at"`
}

func toAppointmentDTO(a repository.Appointment) AppointmentDTO {
	return AppointmentDTO{
		ID: a.ID, Status: a.Status, StartAt: clock.DateTime(a.StartAt), EndAt: clock.DateTime(a.EndAt),
		ServiceID: a.ServiceID, ServiceName: a.ServiceName, DurationMin: a.DurationMin, Price: a.Price,
		DoctorID: a.DoctorID, DoctorName: a.DoctorName, PatientID: a.PatientID, PatientName: a.PatientName,
		BranchName: a.BranchName, InstitutionName: a.InstitutionName, CancelledBy: a.CancelledBy,
		CancelledAt: clock.NullableDateTime(a.CancelledAt), CreatedAt: clock.DateTime(a.CreatedAt),
	}
}

func toAppointmentDTOs(list []repository.Appointment) []AppointmentDTO {
	out := make([]AppointmentDTO, 0, len(list))
	for _, a := range list {
		out = append(out, toAppointmentDTO(a))
	}
	return out
}

// SlotDTO, slot yanıtı.
type SlotDTO struct {
	DoctorID   int64          `json:"doctor_id"`
	DoctorName string         `json:"doctor_name"`
	StartAt    clock.DateTime `json:"start_at"`
	EndAt      clock.DateTime `json:"end_at"`
}

// NotificationDTO, bildirim yanıtı.
type NotificationDTO struct {
	ID            int64                   `json:"id"`
	AppointmentID int64                   `json:"appointment_id"`
	Type          domain.NotificationType `json:"type"`
	Message       string                  `json:"message"`
	IsRead        bool                    `json:"is_read"`
	CreatedAt     clock.DateTime          `json:"created_at"`
}

func toNotificationDTO(n repository.Notification) NotificationDTO {
	return NotificationDTO{
		ID: n.ID, AppointmentID: n.AppointmentID, Type: n.Type, Message: n.Message,
		IsRead: n.IsRead, CreatedAt: clock.DateTime(n.CreatedAt),
	}
}

// NotificationList, bildirim listesi yanıtı: öğeler ve okunmamış sayısı.
type NotificationList struct {
	Items       []NotificationDTO `json:"items"`
	UnreadCount int               `json:"unread_count"`
}

// ---- Ortak yardımcılar ----

var errAppointmentNotFound = apperr.NotFound("Randevu bulunamadı.")

// ParseStatusFilter, isteğe bağlı randevu durumu filtresini doğrular.
func ParseStatusFilter(raw string) (domain.AppointmentStatus, error) {
	if raw == "" {
		return "", nil
	}
	s := domain.AppointmentStatus(raw)
	switch s {
	case domain.AppointmentPending, domain.AppointmentApproved, domain.AppointmentRejected,
		domain.AppointmentCancelled, domain.AppointmentCompleted:
		return s, nil
	}
	return "", apperr.InvalidRequest("Geçersiz durum filtresi. Geçerli değerler: pending, approved, rejected, cancelled, completed.")
}

// ParseDateFilter, isteğe bağlı "YYYY-MM-DD" filtresini çözer.
func ParseDateFilter(raw, field string) (*time.Time, error) {
	if raw == "" {
		return nil, nil
	}
	d, err := clock.ParseDate(raw)
	if err != nil {
		return nil, apperr.InvalidRequest(field + " YYYY-MM-DD biçiminde olmalıdır.")
	}
	return &d, nil
}

// displayTime, bildirim metinlerinde kullanılan "20.11.2026 09:30" biçimi.
func displayTime(t time.Time) string {
	return t.In(clock.Location).Format("02.01.2006 15:04")
}

// notificationMessage, bildirim türüne göre Türkçe mesaj üretir.
func notificationMessage(t domain.NotificationType, a repository.Appointment) string {
	when := displayTime(a.StartAt)
	switch t {
	case domain.NotificationApproved:
		return fmt.Sprintf("Dr. %s, %s tarihli %s randevunuzu onayladı.", a.DoctorName, when, a.ServiceName)
	case domain.NotificationRejected:
		return fmt.Sprintf("Dr. %s, %s tarihli %s randevu talebinizi reddetti.", a.DoctorName, when, a.ServiceName)
	case domain.NotificationCancelledByDoctor:
		return fmt.Sprintf("Dr. %s, %s tarihli %s randevunuzu iptal etti.", a.DoctorName, when, a.ServiceName)
	case domain.NotificationCancelledByAdmin:
		return fmt.Sprintf("%s yönetimi, Dr. %s ile %s tarihli %s randevunuzu iptal etti.", a.InstitutionName, a.DoctorName, when, a.ServiceName)
	case domain.NotificationCancelledAuto:
		return fmt.Sprintf("Dr. %s ile %s tarihli %s randevunuz, zamanında onaylanmadığı için otomatik olarak iptal edildi.", a.DoctorName, when, a.ServiceName)
	}
	return "Randevunuzun durumu değişti."
}

// notify, hastaya bildirim yazar. Durumu değiştiren işlemle aynı db işleminde çağrılır.
func notify(ctx context.Context, tx *sql.Tx, t domain.NotificationType, a repository.Appointment, now time.Time) error {
	return repository.InsertNotification(ctx, tx, repository.Notification{
		UserID: a.PatientID, AppointmentID: a.ID, Type: t, Message: notificationMessage(t, a), CreatedAt: now,
	})
}

// applyCancel, kilitli randevuya iptal politikasını uygular: kural denetimi, durum güncelleme, bildirim.
func applyCancel(ctx context.Context, tx *sql.Tx, a repository.Appointment, policy CancelPolicy, now time.Time) error {
	if err := policy.Check(a, now); err != nil {
		return err
	}
	actor := policy.Actor()
	if err := repository.SetAppointmentStatus(ctx, tx, a.ID, domain.AppointmentCancelled, &actor, now); err != nil {
		return err
	}
	if t, ok := policy.Notification(); ok {
		return notify(ctx, tx, t, a, now)
	}
	return nil
}

// cancel, randevuyu kilitler, sahipliği denetler ve politikaya göre iptal eder.
// Sahibi olmayan kullanıcı için NOT_FOUND döner (başka kayıtların varlığı sızdırılmaz).
func (s *AppointmentService) cancel(ctx context.Context, id int64, owns func(repository.Appointment) bool, policy CancelPolicy) (AppointmentDTO, error) {
	var result repository.Appointment
	err := repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		a, err := repository.AppointmentByID(ctx, tx, id, true)
		if errors.Is(err, repository.ErrNotFound) || (err == nil && !owns(a)) {
			return errAppointmentNotFound
		}
		if err != nil {
			return err
		}
		if err := applyCancel(ctx, tx, a, policy, s.now()); err != nil {
			return err
		}
		result, err = repository.AppointmentByID(ctx, tx, id, false)
		return err
	})
	if err != nil {
		return AppointmentDTO{}, err
	}
	return toAppointmentDTO(result), nil
}

// ---- Hasta: arama ----

// PublicInstitutions, aktif kurumlar.
func (s *AppointmentService) PublicInstitutions(ctx context.Context) ([]InstitutionDTO, error) {
	list, err := repository.ListInstitutions(ctx, s.db, true)
	if err != nil {
		return nil, err
	}
	out := make([]InstitutionDTO, 0, len(list))
	for _, i := range list {
		out = append(out, toInstitutionDTO(i))
	}
	return out, nil
}

// PublicBranches, aktif kurumun aktif şubeleri.
func (s *AppointmentService) PublicBranches(ctx context.Context, institutionID int64) ([]BranchDTO, error) {
	inst, err := repository.InstitutionByID(ctx, s.db, institutionID)
	if errors.Is(err, repository.ErrNotFound) || (err == nil && !inst.IsActive) {
		return nil, apperr.NotFound("Kurum bulunamadı.")
	}
	if err != nil {
		return nil, err
	}
	list, err := repository.ListBranches(ctx, s.db, institutionID, true)
	if err != nil {
		return nil, err
	}
	out := make([]BranchDTO, 0, len(list))
	for _, b := range list {
		out = append(out, toBranchDTO(b))
	}
	return out, nil
}

// PublicDepartments, aktif şubenin aktif bölümleri.
func (s *AppointmentService) PublicDepartments(ctx context.Context, branchID int64) ([]DepartmentDTO, error) {
	notFound := apperr.NotFound("Şube bulunamadı.")
	b, err := repository.BranchByID(ctx, s.db, branchID)
	if errors.Is(err, repository.ErrNotFound) || (err == nil && !b.IsActive) {
		return nil, notFound
	}
	if err != nil {
		return nil, err
	}
	inst, err := repository.InstitutionByID(ctx, s.db, b.InstitutionID)
	if err != nil {
		return nil, err
	}
	if !inst.IsActive {
		return nil, notFound
	}
	list, err := repository.ListDepartments(ctx, s.db, b.InstitutionID, branchID, true)
	if err != nil {
		return nil, err
	}
	out := make([]DepartmentDTO, 0, len(list))
	for _, d := range list {
		out = append(out, toDepartmentDTO(d))
	}
	return out, nil
}

// PublicServices, bölümün aktif hizmetleri (bölüm, şube ve kurum da aktif olmalı).
func (s *AppointmentService) PublicServices(ctx context.Context, departmentID int64) ([]ServiceDTO, error) {
	if departmentID <= 0 {
		return nil, apperr.InvalidRequest("department_id zorunludur.")
	}
	if _, err := repository.DepartmentByID(ctx, s.db, departmentID); errors.Is(err, repository.ErrNotFound) {
		return nil, apperr.NotFound("Bölüm bulunamadı.")
	} else if err != nil {
		return nil, err
	}
	list, err := repository.ListServices(ctx, s.db, repository.ServiceFilter{DepartmentID: departmentID, OnlyActive: true})
	if err != nil {
		return nil, err
	}
	out := make([]ServiceDTO, 0, len(list))
	for _, sv := range list {
		out = append(out, toServiceDTO(sv))
	}
	return out, nil
}

// ---- Hasta: slotlar ve randevu ----

// SlotQuery, slot isteğidir. Tarihler isteğe bağlıdır (varsayılan: bugünden 7 gün sonrasına kadar).
type SlotQuery struct {
	ServiceID int64
	DoctorID  int64
	DateFrom  string
	DateTo    string
}

// bookableService, hastanın randevu alabileceği hizmeti getirir; yoksa veya pasifse NOT_FOUND.
// lock true ise aktiflik zinciri paylaşımlı kilitle okunur (randevu oluşturma işleminde).
func bookableService(ctx context.Context, q repository.DBTX, id int64, lock bool) (repository.Service, error) {
	notFound := apperr.NotFound("Hizmet bulunamadı.")
	sv, err := repository.ServiceByID(ctx, q, id)
	if errors.Is(err, repository.ErrNotFound) {
		return sv, notFound
	}
	if err != nil {
		return sv, err
	}
	ok, err := repository.ServiceIsBookable(ctx, q, id, lock)
	if err != nil {
		return sv, err
	}
	if !ok {
		return sv, notFound
	}
	return sv, nil
}

// doctorSchedules, doktorların uygunluklarını ve [from, to) içindeki dolu aralıklarını yükler.
func doctorSchedules(ctx context.Context, q repository.DBTX, doctors []repository.Doctor, from, to time.Time, withBusy bool) ([]DoctorSchedule, error) {
	ids := make([]int64, 0, len(doctors))
	for _, d := range doctors {
		ids = append(ids, d.ID)
	}
	busy := map[int64][]repository.Interval{}
	if withBusy {
		var err error
		if busy, err = repository.DoctorBusyIntervals(ctx, q, ids, from, to); err != nil {
			return nil, err
		}
	}
	out := make([]DoctorSchedule, 0, len(doctors))
	for _, d := range doctors {
		avail, err := repository.AvailabilityOf(ctx, q, d.ID)
		if err != nil {
			return nil, err
		}
		out = append(out, DoctorSchedule{
			DoctorID: d.ID, DoctorName: d.FirstName + " " + d.LastName, Availability: avail, Busy: busy[d.ID],
		})
	}
	return out, nil
}

// Slots, hizmet için uygun slotları döndürür.
func (s *AppointmentService) Slots(ctx context.Context, in SlotQuery) ([]SlotDTO, error) {
	if in.ServiceID <= 0 {
		return nil, apperr.InvalidRequest("service_id zorunludur.")
	}
	now := s.now()
	today := startOfDay(now)
	from, to := today, today.AddDate(0, 0, BookingHorizonDays)
	if d, err := ParseDateFilter(in.DateFrom, "date_from"); err != nil {
		return nil, err
	} else if d != nil {
		from = *d
	}
	if d, err := ParseDateFilter(in.DateTo, "date_to"); err != nil {
		return nil, err
	} else if d != nil {
		to = *d
	}
	if to.Before(from) {
		return nil, apperr.InvalidRequest("date_to, date_from tarihinden önce olamaz.")
	}

	sv, err := bookableService(ctx, s.db, in.ServiceID, false)
	if err != nil {
		return nil, err
	}
	doctors, err := repository.ActiveDoctorsForService(ctx, s.db, sv.ID)
	if err != nil {
		return nil, err
	}
	if in.DoctorID > 0 {
		i := slices.IndexFunc(doctors, func(d repository.Doctor) bool { return d.ID == in.DoctorID })
		if i < 0 {
			return nil, apperr.NotFound("Bu hizmeti veren doktor bulunamadı.")
		}
		doctors = doctors[i : i+1]
	}
	hours, err := repository.WorkingHoursOf(ctx, s.db, sv.BranchID)
	if err != nil {
		return nil, err
	}
	_, horizonEnd := BookingWindow(now)
	schedules, err := doctorSchedules(ctx, s.db, doctors, today, horizonEnd, true)
	if err != nil {
		return nil, err
	}
	slots := GenerateSlots(SlotRequest{
		Now: now, DateFrom: from, DateTo: to, DurationMin: sv.DurationMin, WorkingHours: hours, Doctors: schedules,
	})
	out := make([]SlotDTO, 0, len(slots))
	for _, sl := range slots {
		out = append(out, SlotDTO{DoctorID: sl.DoctorID, DoctorName: sl.DoctorName, StartAt: clock.DateTime(sl.Start), EndAt: clock.DateTime(sl.End)})
	}
	return out, nil
}

// CreateAppointmentInput, randevu isteğidir.
type CreateAppointmentInput struct {
	ServiceID int64           `json:"service_id"`
	DoctorID  int64           `json:"doctor_id"`
	StartAt   *clock.DateTime `json:"start_at"`
}

// CreateAppointment, hastanın seçtiği slota "pending" randevu oluşturur.
// Doktor ve hasta satırları kilitlenir; böylece aynı slota veya aynı hastaya eşzamanlı iki randevu yazılamaz.
func (s *AppointmentService) CreateAppointment(ctx context.Context, patientID int64, in CreateAppointmentInput) (AppointmentDTO, error) {
	if in.ServiceID <= 0 || in.DoctorID <= 0 || in.StartAt == nil {
		return AppointmentDTO{}, apperr.InvalidRequest("service_id, doctor_id ve start_at zorunludur.")
	}
	start := in.StartAt.Time()
	now := s.now()

	var result repository.Appointment
	err := repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		// Kilitler işlemin ilk ifadeleridir: sonraki okumalar kilit alındıktan sonraki güncel veriyi görür.
		if err := repository.LockDoctor(ctx, tx, in.DoctorID); errors.Is(err, repository.ErrNotFound) {
			return apperr.NotFound("Doktor bulunamadı.")
		} else if err != nil {
			return err
		}
		if err := repository.LockPatient(ctx, tx, patientID); err != nil {
			return err
		}

		sv, err := bookableService(ctx, tx, in.ServiceID, true)
		if err != nil {
			return err
		}
		doc, err := repository.DoctorByID(ctx, tx, in.DoctorID, false)
		if err != nil {
			return err
		}
		if !doc.IsActive || doc.DepartmentID != sv.DepartmentID || !slices.Contains(doc.ServiceIDs, sv.ID) {
			return apperr.BusinessRule("Seçilen doktor bu hizmeti vermiyor.")
		}

		// İstenen başlangıç, kurallara göre üretilebilen bir slot olmalı (doluluk ayrıca denetlenir).
		hours, err := repository.WorkingHoursOf(ctx, tx, sv.BranchID)
		if err != nil {
			return err
		}
		schedules, err := doctorSchedules(ctx, tx, []repository.Doctor{doc}, start, start, false)
		if err != nil {
			return err
		}
		valid := GenerateSlots(SlotRequest{
			Now: now, DateFrom: start, DateTo: start, DurationMin: sv.DurationMin, WorkingHours: hours, Doctors: schedules,
		})
		if !slices.ContainsFunc(valid, func(sl Slot) bool { return sl.Start.Equal(start) }) {
			return apperr.BusinessRule("Seçilen saat geçerli bir randevu saati değil (çalışma saati, öğle arası, en erken 24 saat sonrası ve en fazla 7 gün kuralları). Lütfen listelenen saatlerden birini seçin.")
		}
		end := start.Add(time.Duration(sv.DurationMin) * time.Minute)

		busy, err := repository.DoctorBusyIntervals(ctx, tx, []int64{doc.ID}, start, end)
		if err != nil {
			return err
		}
		if len(busy[doc.ID]) > 0 {
			return apperr.SlotTaken()
		}
		conflict, err := repository.PatientHasActiveOverlap(ctx, tx, patientID, start, end)
		if err != nil {
			return err
		}
		if conflict {
			return apperr.PatientConflict()
		}

		id, err := repository.InsertAppointment(ctx, tx, repository.NewAppointment{
			PatientID: patientID, DoctorID: doc.ID, ServiceID: sv.ID, StartAt: start, EndAt: end,
			ServiceName: sv.Name, DurationMin: sv.DurationMin, Price: sv.Price,
		}, now)
		if err != nil {
			return err
		}
		result, err = repository.AppointmentByID(ctx, tx, id, false)
		return err
	})
	if err != nil {
		return AppointmentDTO{}, err
	}
	return toAppointmentDTO(result), nil
}

// MyAppointments, hastanın randevuları (yeniden eskiye).
func (s *AppointmentService) MyAppointments(ctx context.Context, patientID int64) ([]AppointmentDTO, error) {
	list, err := repository.ListAppointments(ctx, s.db, repository.AppointmentFilter{PatientID: patientID, NewestFirst: true})
	if err != nil {
		return nil, err
	}
	return toAppointmentDTOs(list), nil
}

// PatientCancel, hastanın kendi randevusunu iptal eder.
func (s *AppointmentService) PatientCancel(ctx context.Context, patientID, id int64) (AppointmentDTO, error) {
	return s.cancel(ctx, id, func(a repository.Appointment) bool { return a.PatientID == patientID }, PatientCancelPolicy{})
}

// ---- Hasta: bildirimler ----

// MyNotifications, hastanın bildirimleri ve okunmamış sayısı.
func (s *AppointmentService) MyNotifications(ctx context.Context, userID int64, onlyUnread bool) (NotificationList, error) {
	list, err := repository.ListNotifications(ctx, s.db, userID, onlyUnread)
	if err != nil {
		return NotificationList{}, err
	}
	count, err := repository.UnreadNotificationCount(ctx, s.db, userID)
	if err != nil {
		return NotificationList{}, err
	}
	items := make([]NotificationDTO, 0, len(list))
	for _, n := range list {
		items = append(items, toNotificationDTO(n))
	}
	return NotificationList{Items: items, UnreadCount: count}, nil
}

// MarkNotificationRead, kullanıcının bildirimini okundu işaretler.
func (s *AppointmentService) MarkNotificationRead(ctx context.Context, userID, id int64) (NotificationDTO, error) {
	n, err := repository.NotificationByID(ctx, s.db, id)
	if errors.Is(err, repository.ErrNotFound) || (err == nil && n.UserID != userID) {
		return NotificationDTO{}, apperr.NotFound("Bildirim bulunamadı.")
	}
	if err != nil {
		return NotificationDTO{}, err
	}
	if !n.IsRead {
		if err := repository.MarkNotificationRead(ctx, s.db, id); err != nil {
			return NotificationDTO{}, err
		}
		n.IsRead = true
	}
	return toNotificationDTO(n), nil
}

// MarkAllNotificationsRead, tüm bildirimleri okundu işaretler; değişen sayıyı döndürür.
func (s *AppointmentService) MarkAllNotificationsRead(ctx context.Context, userID int64) (int64, error) {
	return repository.MarkAllNotificationsRead(ctx, s.db, userID)
}

// ---- Doktor ----

// DoctorAppointments, doktorun randevuları (eskiden yeniye).
func (s *AppointmentService) DoctorAppointments(ctx context.Context, doctorID int64, status, date string) ([]AppointmentDTO, error) {
	st, err := ParseStatusFilter(status)
	if err != nil {
		return nil, err
	}
	day, err := ParseDateFilter(date, "date")
	if err != nil {
		return nil, err
	}
	list, err := repository.ListAppointments(ctx, s.db, repository.AppointmentFilter{DoctorID: doctorID, Status: st, Day: day})
	if err != nil {
		return nil, err
	}
	return toAppointmentDTOs(list), nil
}

// decide, doktorun bekleyen randevuyu onaylaması veya reddetmesidir; bildirim aynı işlemde yazılır.
func (s *AppointmentService) decide(ctx context.Context, doctorID, id int64, approve bool) (AppointmentDTO, error) {
	var result repository.Appointment
	err := repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		a, err := repository.AppointmentByID(ctx, tx, id, true)
		if errors.Is(err, repository.ErrNotFound) || (err == nil && a.DoctorID != doctorID) {
			return errAppointmentNotFound
		}
		if err != nil {
			return err
		}
		if a.Status != domain.AppointmentPending {
			return apperr.BusinessRule("Yalnızca onay bekleyen randevuya karar verilebilir.")
		}
		now := s.now()
		status, notice := domain.AppointmentRejected, domain.NotificationRejected
		if approve {
			if a.StartAt.Sub(now) < ApprovalDeadline {
				return apperr.BusinessRule("Onay süresi doldu: randevuya 12 saatten az kaldı.")
			}
			status, notice = domain.AppointmentApproved, domain.NotificationApproved
		}
		if err := repository.SetAppointmentStatus(ctx, tx, id, status, nil, now); err != nil {
			return err
		}
		if err := notify(ctx, tx, notice, a, now); err != nil {
			return err
		}
		result, err = repository.AppointmentByID(ctx, tx, id, false)
		return err
	})
	if err != nil {
		return AppointmentDTO{}, err
	}
	return toAppointmentDTO(result), nil
}

// DoctorApprove, bekleyen randevuyu onaylar.
func (s *AppointmentService) DoctorApprove(ctx context.Context, doctorID, id int64) (AppointmentDTO, error) {
	return s.decide(ctx, doctorID, id, true)
}

// DoctorReject, bekleyen randevuyu reddeder; slot açılır.
func (s *AppointmentService) DoctorReject(ctx context.Context, doctorID, id int64) (AppointmentDTO, error) {
	return s.decide(ctx, doctorID, id, false)
}

// DoctorCancel, doktorun onayladığı randevuyu iptal eder.
func (s *AppointmentService) DoctorCancel(ctx context.Context, doctorID, id int64) (AppointmentDTO, error) {
	return s.cancel(ctx, id, func(a repository.Appointment) bool { return a.DoctorID == doctorID }, DoctorCancelPolicy{})
}

// ---- Kurum yöneticisi ----

// ManageAppointmentsQuery, yönetici randevu listesi filtresidir.
type ManageAppointmentsQuery struct {
	Date     string
	DoctorID int64
	Status   string
}

// InstitutionAppointments, kurumun randevuları (eskiden yeniye).
func (s *AppointmentService) InstitutionAppointments(ctx context.Context, institutionID int64, in ManageAppointmentsQuery) ([]AppointmentDTO, error) {
	st, err := ParseStatusFilter(in.Status)
	if err != nil {
		return nil, err
	}
	day, err := ParseDateFilter(in.Date, "date")
	if err != nil {
		return nil, err
	}
	list, err := repository.ListAppointments(ctx, s.db, repository.AppointmentFilter{
		InstitutionID: institutionID, DoctorID: in.DoctorID, Status: st, Day: day,
	})
	if err != nil {
		return nil, err
	}
	return toAppointmentDTOs(list), nil
}

// AdminCancel, kurumdaki aktif randevuyu iptal eder.
func (s *AppointmentService) AdminCancel(ctx context.Context, institutionID, id int64) (AppointmentDTO, error) {
	return s.cancel(ctx, id, func(a repository.Appointment) bool { return a.InstitutionID == institutionID }, AdminCancelPolicy{})
}

// ---- Zamanlanmış iş ----

// MaintenanceResult, zamanlanmış işin bir turunun sonucudur.
type MaintenanceResult struct {
	AutoCancelled int
	Completed     int64
}

// RunMaintenance, dakikalık işi bir kez çalıştırır:
// başlangıcına 12 saatten az kalan bekleyen randevuları iptal eder (bildirimle) ve bitişi geçen onaylıları tamamlar.
func (s *AppointmentService) RunMaintenance(ctx context.Context) (MaintenanceResult, error) {
	var res MaintenanceResult
	now := s.now()
	err := repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		ids, err := repository.ExpiredPendingIDs(ctx, tx, now.Add(ApprovalDeadline))
		if err != nil {
			return err
		}
		for _, id := range ids {
			a, err := repository.AppointmentByID(ctx, tx, id, false)
			if err != nil {
				return err
			}
			if err := applyCancel(ctx, tx, a, SystemCancelPolicy{}, now); err != nil {
				return err
			}
			res.AutoCancelled++
		}
		return nil
	})
	if err != nil {
		return res, err
	}
	res.Completed, err = repository.CompleteFinished(ctx, s.db, now)
	return res, err
}
