package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"hospital/backend/internal/domain"
)

// User, users tablosundaki bir satırdır. InstitutionID yalnızca kurum yöneticisinde doludur.
type User struct {
	ID                 int64
	Role               domain.Role
	FirstName          string
	LastName           string
	Email              string
	Phone              string
	PasswordHash       string
	MustChangePassword bool
	InstitutionID      int64
}

// FullName, "Ad Soyad".
func (u User) FullName() string { return u.FirstName + " " + u.LastName }

const userSelect = `
SELECT u.id, u.role, u.first_name, u.last_name, u.email, COALESCE(u.phone, ''),
       u.password_hash, u.must_change_password, COALESCE(ia.institution_id, 0)
FROM users u
LEFT JOIN institution_admins ia ON ia.user_id = u.id`

func scanUser(row *sql.Row) (User, error) {
	var u User
	err := row.Scan(&u.ID, &u.Role, &u.FirstName, &u.LastName, &u.Email, &u.Phone,
		&u.PasswordHash, &u.MustChangePassword, &u.InstitutionID)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, ErrNotFound
	}
	return u, err
}

// UserByEmail, e-postaya göre kullanıcıyı getirir (e-posta küçük harfle verilmelidir).
func UserByEmail(ctx context.Context, q DBTX, email string) (User, error) {
	return scanUser(q.QueryRowContext(ctx, userSelect+` WHERE u.email = ?`, email))
}

// UserByID, id'ye göre kullanıcıyı getirir.
func UserByID(ctx context.Context, q DBTX, id int64) (User, error) {
	return scanUser(q.QueryRowContext(ctx, userSelect+` WHERE u.id = ?`, id))
}

// EmailInUse, e-posta bir kullanıcıda veya bekleyen bir kurum başvurusunda kullanılıyor mu?
func EmailInUse(ctx context.Context, q DBTX, email string) (bool, error) {
	var n int
	err := q.QueryRowContext(ctx, `
		SELECT (SELECT COUNT(*) FROM users WHERE email = ?)
		     + (SELECT COUNT(*) FROM institution_applications WHERE admin_email = ? AND status = 'pending')`,
		email, email).Scan(&n)
	return n > 0, err
}

// NationalIDInUse, TC kimlik numarası kayıtlı mı?
func NationalIDInUse(ctx context.Context, q DBTX, nationalID string) (bool, error) {
	var n int
	err := q.QueryRowContext(ctx, `SELECT COUNT(*) FROM patients WHERE national_id = ?`, nationalID).Scan(&n)
	return n > 0, err
}

// NewUser, oluşturulacak kullanıcının alanlarıdır.
type NewUser struct {
	Role               domain.Role
	FirstName          string
	LastName           string
	Email              string
	Phone              string
	PasswordHash       string
	MustChangePassword bool
}

// InsertUser, users tablosuna satır ekler ve id döndürür.
func InsertUser(ctx context.Context, q DBTX, u NewUser, now time.Time) (int64, error) {
	res, err := q.ExecContext(ctx, `
		INSERT INTO users (role, first_name, last_name, email, phone, password_hash, must_change_password, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		u.Role, u.FirstName, u.LastName, u.Email, nullString(u.Phone), u.PasswordHash, u.MustChangePassword, now)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// InsertPatient, patients tablosuna satır ekler.
func InsertPatient(ctx context.Context, q DBTX, userID int64, nationalID string) error {
	_, err := q.ExecContext(ctx, `INSERT INTO patients (user_id, national_id) VALUES (?, ?)`, userID, nationalID)
	return err
}

// SetPassword, şifre özetini ve geçici şifre işaretini günceller.
func SetPassword(ctx context.Context, q DBTX, userID int64, hash string, mustChange bool) error {
	res, err := q.ExecContext(ctx,
		`UPDATE users SET password_hash = ?, must_change_password = ? WHERE id = ?`, hash, mustChange, userID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	return nil
}

// LatestApplicationByAdminEmail, e-postaya ait en son kurum başvurusunun durumunu ve şifre özetini döndürür.
func LatestApplicationByAdminEmail(ctx context.Context, q DBTX, email string) (domain.ApplicationStatus, string, error) {
	var status domain.ApplicationStatus
	var hash string
	err := q.QueryRowContext(ctx, `
		SELECT status, admin_password_hash FROM institution_applications
		WHERE admin_email = ? ORDER BY id DESC LIMIT 1`, email).Scan(&status, &hash)
	if errors.Is(err, sql.ErrNoRows) {
		return "", "", ErrNotFound
	}
	return status, hash, err
}
