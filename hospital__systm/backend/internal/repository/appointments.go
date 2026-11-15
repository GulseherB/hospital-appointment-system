package repository

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"

	"hospital/backend/internal/domain"
)

// Appointment, randevu satırı ile gösterim için gereken adların birleşimidir.
// Şube ve kurum, hizmetin bölümü üzerinden bulunur (doktor şube değiştirse de geçmiş randevu doğru kalır).
type Appointment struct {
	ID              int64
	Status          domain.AppointmentStatus
	StartAt         time.Time
	EndAt           time.Time
	ServiceID       int64
	ServiceName     string
	DurationMin     int
	Price           string
	DoctorID        int64
	DoctorName      string
	PatientID       int64
	PatientName     string
	BranchName      string
	InstitutionID   int64
	InstitutionName string
	CancelledBy     *domain.CancelledBy
	CancelledAt     *time.Time
	CreatedAt       time.Time
}

const appointmentSelect = `
SELECT a.id, a.status, a.start_at, a.end_at, a.service_id, a.service_name, a.duration_min, a.price,
       a.doctor_id, CONCAT(du.first_name, ' ', du.last_name), a.patient_id, CONCAT(pu.first_name, ' ', pu.last_name),
       b.name, i.id, i.name, a.cancelled_by, a.cancelled_at, a.created_at
FROM appointments a
JOIN users du ON du.id = a.doctor_id
JOIN users pu ON pu.id = a.patient_id
JOIN services s ON s.id = a.service_id
JOIN departments dep ON dep.id = s.department_id
JOIN branches b ON b.id = dep.branch_id
JOIN institutions i ON i.id = b.institution_id`

func scanAppointment(s scanner) (Appointment, error) {
	var a Appointment
	var cancelledBy sql.NullString
	var cancelledAt sql.NullTime
	err := s.Scan(&a.ID, &a.Status, &a.StartAt, &a.EndAt, &a.ServiceID, &a.ServiceName, &a.DurationMin, &a.Price,
		&a.DoctorID, &a.DoctorName, &a.PatientID, &a.PatientName, &a.BranchName, &a.InstitutionID, &a.InstitutionName,
		&cancelledBy, &cancelledAt, &a.CreatedAt)
	if err != nil {
		return a, err
	}
	if cancelledBy.Valid {
		c := domain.CancelledBy(cancelledBy.String)
		a.CancelledBy = &c
	}
	if cancelledAt.Valid {
		t := cancelledAt.Time
		a.CancelledAt = &t
	}
	return a, nil
}

// AppointmentByID, randevuyu getirir. forUpdate true ise yalnızca randevu satırı kilitlenir.
func AppointmentByID(ctx context.Context, q DBTX, id int64, forUpdate bool) (Appointment, error) {
	query := appointmentSelect + ` WHERE a.id = ?`
	if forUpdate {
		query += ` FOR UPDATE OF a`
	}
	a, err := scanAppointment(q.QueryRowContext(ctx, query, id))
	if errors.Is(err, sql.ErrNoRows) {
		return Appointment{}, ErrNotFound
	}
	return a, err
}

// AppointmentFilter, randevu listesi filtresidir. Sıfır değerli alanlar uygulanmaz.
type AppointmentFilter struct {
	PatientID     int64
	DoctorID      int64
	InstitutionID int64
	Status        domain.AppointmentStatus
	Day           *time.Time // yalnızca o günün randevuları
	NewestFirst   bool
}

// ListAppointments, filtreye uyan randevuları döndürür.
func ListAppointments(ctx context.Context, q DBTX, f AppointmentFilter) ([]Appointment, error) {
	var where []string
	var args []any
	if f.PatientID > 0 {
		where, args = append(where, `a.patient_id = ?`), append(args, f.PatientID)
	}
	if f.DoctorID > 0 {
		where, args = append(where, `a.doctor_id = ?`), append(args, f.DoctorID)
	}
	if f.InstitutionID > 0 {
		where, args = append(where, `i.id = ?`), append(args, f.InstitutionID)
	}
	if f.Status != "" {
		where, args = append(where, `a.status = ?`), append(args, f.Status)
	}
	if f.Day != nil {
		where, args = append(where, `a.start_at >= ? AND a.start_at < ?`), append(args, *f.Day, f.Day.AddDate(0, 0, 1))
	}
	query := appointmentSelect
	if len(where) > 0 {
		query += ` WHERE ` + strings.Join(where, ` AND `)
	}
	if f.NewestFirst {
		query += ` ORDER BY a.start_at DESC, a.id DESC`
	} else {
		query += ` ORDER BY a.start_at, a.id`
	}
	rows, err := q.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Appointment
	for rows.Next() {
		a, err := scanAppointment(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, a)
	}
	return list, rows.Err()
}

// Interval, [Start, End) zaman aralığıdır.
type Interval struct {
	Start time.Time
	End   time.Time
}

// slotHoldingStatuses, slotu dolu sayan durumlardır (pending, approved, completed).
const slotHoldingStatuses = `('pending','approved','completed')`

// DoctorBusyIntervals, doktorların [from, to) aralığıyla kesişen dolu randevu aralıklarını döndürür.
func DoctorBusyIntervals(ctx context.Context, q DBTX, doctorIDs []int64, from, to time.Time) (map[int64][]Interval, error) {
	result := map[int64][]Interval{}
	if len(doctorIDs) == 0 {
		return result, nil
	}
	placeholders := strings.TrimSuffix(strings.Repeat("?,", len(doctorIDs)), ",")
	args := make([]any, 0, len(doctorIDs)+2)
	for _, id := range doctorIDs {
		args = append(args, id)
	}
	args = append(args, to, from)
	rows, err := q.QueryContext(ctx, `
		SELECT doctor_id, start_at, end_at FROM appointments
		WHERE doctor_id IN (`+placeholders+`) AND status IN `+slotHoldingStatuses+`
		  AND start_at < ? AND end_at > ?`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id int64
		var iv Interval
		if err := rows.Scan(&id, &iv.Start, &iv.End); err != nil {
			return nil, err
		}
		result[id] = append(result[id], iv)
	}
	return result, rows.Err()
}

// PatientHasActiveOverlap, hastanın [start, end) ile kesişen aktif (pending/approved) randevusu var mı.
func PatientHasActiveOverlap(ctx context.Context, q DBTX, patientID int64, start, end time.Time) (bool, error) {
	var n int
	err := q.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM appointments
		WHERE patient_id = ? AND status IN ('pending','approved') AND start_at < ? AND end_at > ?`,
		patientID, end, start).Scan(&n)
	return n > 0, err
}

// LockDoctor, doktor satırını kilitler (aynı doktora eşzamanlı randevu oluşturmayı sıraya sokar).
// İşlemin ilk ifadesi olmalıdır; böylece sonraki okumalar kilitten sonraki güncel veriyi görür.
func LockDoctor(ctx context.Context, tx *sql.Tx, doctorID int64) error {
	var id int64
	err := tx.QueryRowContext(ctx, `SELECT user_id FROM doctors WHERE user_id = ? FOR UPDATE`, doctorID).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	return err
}

// LockPatient, hasta satırını kilitler (aynı hastanın eşzamanlı randevularını sıraya sokar).
// Kilit sırası her zaman önce doktor, sonra hastadır; böylece kilitlenme döngüsü oluşmaz.
func LockPatient(ctx context.Context, tx *sql.Tx, patientID int64) error {
	var id int64
	err := tx.QueryRowContext(ctx, `SELECT user_id FROM patients WHERE user_id = ? FOR UPDATE`, patientID).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	return err
}

// NewAppointment, eklenecek randevudur.
type NewAppointment struct {
	PatientID   int64
	DoctorID    int64
	ServiceID   int64
	StartAt     time.Time
	EndAt       time.Time
	ServiceName string
	DurationMin int
	Price       string
}

// InsertAppointment, randevuyu "pending" durumunda ekler.
func InsertAppointment(ctx context.Context, q DBTX, a NewAppointment, now time.Time) (int64, error) {
	res, err := q.ExecContext(ctx, `
		INSERT INTO appointments (patient_id, doctor_id, service_id, start_at, end_at, status,
		                          service_name, duration_min, price, created_at)
		VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)`,
		a.PatientID, a.DoctorID, a.ServiceID, a.StartAt, a.EndAt, a.ServiceName, a.DurationMin, a.Price, now)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// SetAppointmentStatus, durumu değiştirir. cancelledBy nil değilse iptal bilgisi de yazılır.
func SetAppointmentStatus(ctx context.Context, q DBTX, id int64, status domain.AppointmentStatus, cancelledBy *domain.CancelledBy, now time.Time) error {
	if cancelledBy != nil {
		_, err := q.ExecContext(ctx,
			`UPDATE appointments SET status = ?, cancelled_by = ?, cancelled_at = ? WHERE id = ?`,
			status, *cancelledBy, now, id)
		return err
	}
	_, err := q.ExecContext(ctx, `UPDATE appointments SET status = ? WHERE id = ?`, status, id)
	return err
}

// ExpiredPendingIDs, başlangıcı deadline'dan önce olan bekleyen randevuları kilitleyerek döndürür.
func ExpiredPendingIDs(ctx context.Context, tx *sql.Tx, deadline time.Time) ([]int64, error) {
	rows, err := tx.QueryContext(ctx,
		`SELECT id FROM appointments WHERE status = 'pending' AND start_at < ? ORDER BY id FOR UPDATE`, deadline)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// CompleteFinished, bitişi geçmiş onaylı randevuları "completed" yapar ve etkilenen sayıyı döndürür.
func CompleteFinished(ctx context.Context, q DBTX, now time.Time) (int64, error) {
	res, err := q.ExecContext(ctx,
		`UPDATE appointments SET status = 'completed' WHERE status = 'approved' AND end_at <= ?`, now)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

// ---- Bildirimler ----

// Notification, notifications tablosundaki bir satırdır.
type Notification struct {
	ID            int64
	UserID        int64
	AppointmentID int64
	Type          domain.NotificationType
	Message       string
	IsRead        bool
	CreatedAt     time.Time
}

const notificationSelect = `SELECT id, user_id, appointment_id, type, message, is_read, created_at FROM notifications`

func scanNotification(s scanner) (Notification, error) {
	var n Notification
	err := s.Scan(&n.ID, &n.UserID, &n.AppointmentID, &n.Type, &n.Message, &n.IsRead, &n.CreatedAt)
	return n, err
}

// InsertNotification, bildirim ekler.
func InsertNotification(ctx context.Context, q DBTX, n Notification) error {
	_, err := q.ExecContext(ctx, `
		INSERT INTO notifications (user_id, appointment_id, type, message, is_read, created_at)
		VALUES (?, ?, ?, ?, FALSE, ?)`, n.UserID, n.AppointmentID, n.Type, n.Message, n.CreatedAt)
	return err
}

// ListNotifications, kullanıcının bildirimlerini yeniden eskiye döndürür.
func ListNotifications(ctx context.Context, q DBTX, userID int64, onlyUnread bool) ([]Notification, error) {
	query := notificationSelect + ` WHERE user_id = ?`
	if onlyUnread {
		query += ` AND is_read = FALSE`
	}
	rows, err := q.QueryContext(ctx, query+` ORDER BY created_at DESC, id DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Notification
	for rows.Next() {
		n, err := scanNotification(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, n)
	}
	return list, rows.Err()
}

// UnreadNotificationCount, okunmamış bildirim sayısı.
func UnreadNotificationCount(ctx context.Context, q DBTX, userID int64) (int, error) {
	var n int
	err := q.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = FALSE`, userID).Scan(&n)
	return n, err
}

// NotificationByID, bildirimi getirir.
func NotificationByID(ctx context.Context, q DBTX, id int64) (Notification, error) {
	n, err := scanNotification(q.QueryRowContext(ctx, notificationSelect+` WHERE id = ?`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return Notification{}, ErrNotFound
	}
	return n, err
}

// MarkNotificationRead, tek bildirimi okundu yapar.
func MarkNotificationRead(ctx context.Context, q DBTX, id int64) error {
	_, err := q.ExecContext(ctx, `UPDATE notifications SET is_read = TRUE WHERE id = ?`, id)
	return err
}

// MarkAllNotificationsRead, kullanıcının tüm bildirimlerini okundu yapar; değişen sayıyı döndürür.
func MarkAllNotificationsRead(ctx context.Context, q DBTX, userID int64) (int64, error) {
	res, err := q.ExecContext(ctx,
		`UPDATE notifications SET is_read = TRUE WHERE user_id = ? AND is_read = FALSE`, userID)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}
