package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"hospital/backend/internal/domain"
)

// Institution, institutions tablosundaki bir satırdır.
type Institution struct {
	ID       int64
	Name     string
	Type     domain.InstitutionType
	Address  string
	Phone    string
	Email    string
	IsActive bool
}

// ListInstitutions, kurumları döndürür. onlyActive true ise yalnızca aktif olanlar.
func ListInstitutions(ctx context.Context, q DBTX, onlyActive bool) ([]Institution, error) {
	query := `SELECT id, name, type, address, phone, email, is_active FROM institutions`
	if onlyActive {
		query += ` WHERE is_active = TRUE`
	}
	rows, err := q.QueryContext(ctx, query+` ORDER BY name, id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Institution
	for rows.Next() {
		var i Institution
		if err := rows.Scan(&i.ID, &i.Name, &i.Type, &i.Address, &i.Phone, &i.Email, &i.IsActive); err != nil {
			return nil, err
		}
		list = append(list, i)
	}
	return list, rows.Err()
}

// InstitutionByID, kurumu getirir.
func InstitutionByID(ctx context.Context, q DBTX, id int64) (Institution, error) {
	var i Institution
	err := q.QueryRowContext(ctx,
		`SELECT id, name, type, address, phone, email, is_active FROM institutions WHERE id = ?`, id).
		Scan(&i.ID, &i.Name, &i.Type, &i.Address, &i.Phone, &i.Email, &i.IsActive)
	if errors.Is(err, sql.ErrNoRows) {
		return Institution{}, ErrNotFound
	}
	return i, err
}

// InsertInstitution, kurum ekler.
func InsertInstitution(ctx context.Context, q DBTX, i Institution, now time.Time) (int64, error) {
	res, err := q.ExecContext(ctx, `
		INSERT INTO institutions (name, type, address, phone, email, is_active, created_at)
		VALUES (?, ?, ?, ?, ?, TRUE, ?)`, i.Name, i.Type, i.Address, i.Phone, i.Email, now)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// InsertInstitutionAdmin, yöneticiyi kuruma bağlar.
func InsertInstitutionAdmin(ctx context.Context, q DBTX, userID, institutionID int64) error {
	_, err := q.ExecContext(ctx,
		`INSERT INTO institution_admins (user_id, institution_id) VALUES (?, ?)`, userID, institutionID)
	return err
}

// Application, institution_applications tablosundaki bir satırdır.
type Application struct {
	ID                 int64
	Status             domain.ApplicationStatus
	InstitutionName    string
	InstitutionType    domain.InstitutionType
	InstitutionAddress string
	InstitutionPhone   string
	InstitutionEmail   string
	AdminFirstName     string
	AdminLastName      string
	AdminEmail         string
	AdminPhone         string
	AdminPasswordHash  string
	InstitutionID      *int64
	CreatedAt          time.Time
	DecidedAt          *time.Time
}

const applicationSelect = `
SELECT id, status, institution_name, institution_type, institution_address, institution_phone,
       institution_email, admin_first_name, admin_last_name, admin_email, admin_phone,
       admin_password_hash, institution_id, created_at, decided_at
FROM institution_applications`

type scanner interface{ Scan(dest ...any) error }

func scanApplication(s scanner) (Application, error) {
	var a Application
	var instID sql.NullInt64
	var decided sql.NullTime
	err := s.Scan(&a.ID, &a.Status, &a.InstitutionName, &a.InstitutionType, &a.InstitutionAddress,
		&a.InstitutionPhone, &a.InstitutionEmail, &a.AdminFirstName, &a.AdminLastName, &a.AdminEmail,
		&a.AdminPhone, &a.AdminPasswordHash, &instID, &a.CreatedAt, &decided)
	if err != nil {
		return Application{}, err
	}
	if instID.Valid {
		a.InstitutionID = &instID.Int64
	}
	if decided.Valid {
		a.DecidedAt = &decided.Time
	}
	return a, nil
}

// InsertApplication, yeni başvuru ekler (durum pending).
func InsertApplication(ctx context.Context, q DBTX, a Application) (int64, error) {
	res, err := q.ExecContext(ctx, `
		INSERT INTO institution_applications (institution_name, institution_type, institution_address,
		  institution_phone, institution_email, admin_first_name, admin_last_name, admin_email,
		  admin_phone, admin_password_hash, status, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)`,
		a.InstitutionName, a.InstitutionType, a.InstitutionAddress, a.InstitutionPhone, a.InstitutionEmail,
		a.AdminFirstName, a.AdminLastName, a.AdminEmail, a.AdminPhone, a.AdminPasswordHash, a.CreatedAt)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// ApplicationByID, başvuruyu getirir. forUpdate true ise satır işlem sonuna kadar kilitlenir.
func ApplicationByID(ctx context.Context, q DBTX, id int64, forUpdate bool) (Application, error) {
	query := applicationSelect + ` WHERE id = ?`
	if forUpdate {
		query += ` FOR UPDATE`
	}
	a, err := scanApplication(q.QueryRowContext(ctx, query, id))
	if errors.Is(err, sql.ErrNoRows) {
		return Application{}, ErrNotFound
	}
	return a, err
}

// ListApplications, başvuruları yeniden eskiye döndürür; status boşsa hepsi.
func ListApplications(ctx context.Context, q DBTX, status string) ([]Application, error) {
	query := applicationSelect
	var args []any
	if status != "" {
		query += ` WHERE status = ?`
		args = append(args, status)
	}
	rows, err := q.QueryContext(ctx, query+` ORDER BY id DESC`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Application
	for rows.Next() {
		a, err := scanApplication(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, a)
	}
	return list, rows.Err()
}

// DecideApplication, başvurunun durumunu ve karar zamanını günceller.
func DecideApplication(ctx context.Context, q DBTX, id int64, status domain.ApplicationStatus, institutionID *int64, now time.Time) error {
	_, err := q.ExecContext(ctx,
		`UPDATE institution_applications SET status = ?, institution_id = ?, decided_at = ? WHERE id = ?`,
		status, institutionID, now, id)
	return err
}
