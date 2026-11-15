package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"
)

// lockableTables, LockRow ile kilitlenebilecek tablolar ve birincil anahtar sütunlarıdır
// (tablo adı sorguya eklendiği için yalnızca bu listedekiler kabul edilir).
var lockableTables = map[string]string{
	"branches":     "id",
	"departments":  "id",
	"services":     "id",
	"doctors":      "user_id",
	"institutions": "id",
}

// LockRow, satırı işlem sonuna kadar kilitler. Pasifleştirme işlemlerinin ilk ifadesidir:
// randevu oluşturma aynı satırları paylaşımlı kilitle okuduğundan iki işlem sıraya girer
// ve pasifleştirme, kilitten önce kaydedilmiş tüm randevuları görür.
func LockRow(ctx context.Context, tx *sql.Tx, table string, id int64) error {
	key, ok := lockableTables[table]
	if !ok {
		return errors.New("kilitlenemeyen tablo: " + table)
	}
	var got int64
	err := tx.QueryRowContext(ctx, `SELECT `+key+` FROM `+table+` WHERE `+key+` = ? FOR UPDATE`, id).Scan(&got)
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	return err
}

// FutureScope, gelecekteki aktif randevu sayımının kapsamıdır; tam olarak bir alan dolu olmalıdır.
type FutureScope struct {
	BranchID     int64
	DepartmentID int64
	ServiceID    int64
	DoctorID     int64
}

// FutureActiveAppointments, kapsamda başlangıcı now'dan sonra olan bekleyen/onaylı randevu sayısı.
// Şube ve bölüm, randevunun hizmeti üzerinden bulunur.
func FutureActiveAppointments(ctx context.Context, q DBTX, scope FutureScope, now time.Time) (int, error) {
	query := `
		SELECT COUNT(*) FROM appointments a
		JOIN services s ON s.id = a.service_id
		JOIN departments d ON d.id = s.department_id
		WHERE a.status IN ('pending','approved') AND a.start_at > ?`
	args := []any{now}
	switch {
	case scope.BranchID > 0:
		query += ` AND d.branch_id = ?`
		args = append(args, scope.BranchID)
	case scope.DepartmentID > 0:
		query += ` AND s.department_id = ?`
		args = append(args, scope.DepartmentID)
	case scope.ServiceID > 0:
		query += ` AND a.service_id = ?`
		args = append(args, scope.ServiceID)
	case scope.DoctorID > 0:
		query += ` AND a.doctor_id = ?`
		args = append(args, scope.DoctorID)
	default:
		return 0, errors.New("FutureScope boş")
	}
	var n int
	err := q.QueryRowContext(ctx, query, args...).Scan(&n)
	return n, err
}

// UpdateBranch, şube bilgilerini ve aktiflik durumunu günceller.
func UpdateBranch(ctx context.Context, q DBTX, b Branch) error {
	_, err := q.ExecContext(ctx, `UPDATE branches SET name = ?, address = ?, phone = ?, is_active = ? WHERE id = ?`,
		b.Name, nullString(b.Address), nullString(b.Phone), b.IsActive, b.ID)
	return err
}

// UpdateDepartment, bölüm adını ve aktiflik durumunu günceller.
func UpdateDepartment(ctx context.Context, q DBTX, id int64, name string, active bool) error {
	_, err := q.ExecContext(ctx, `UPDATE departments SET name = ?, is_active = ? WHERE id = ?`, name, active, id)
	return err
}

// UpdateService, hizmeti günceller. Mevcut randevular etkilenmez (ad, süre, ücret randevuya kopyalanmıştır).
func UpdateService(ctx context.Context, q DBTX, id int64, name string, durationMin int, price string, active bool) error {
	_, err := q.ExecContext(ctx,
		`UPDATE services SET name = ?, duration_min = ?, price = ?, is_active = ? WHERE id = ?`,
		name, durationMin, price, active, id)
	return err
}

// UpdateDoctor, doktorun kullanıcı ve doktor bilgilerini günceller (e-posta değişmez).
func UpdateDoctor(ctx context.Context, q DBTX, d Doctor) error {
	if _, err := q.ExecContext(ctx, `UPDATE users SET first_name = ?, last_name = ?, phone = ? WHERE id = ?`,
		d.FirstName, d.LastName, nullString(d.Phone), d.ID); err != nil {
		return err
	}
	_, err := q.ExecContext(ctx,
		`UPDATE doctors SET branch_id = ?, department_id = ?, specialty = ?, is_active = ? WHERE user_id = ?`,
		d.BranchID, d.DepartmentID, d.Specialty, d.IsActive, d.ID)
	return err
}

// RemoveDoctorServicesOutside, doktorun departmentID dışındaki hizmet atamalarını siler ve silinen id'leri döndürür.
func RemoveDoctorServicesOutside(ctx context.Context, q DBTX, doctorID, departmentID int64) ([]int64, error) {
	rows, err := q.QueryContext(ctx, `
		SELECT ds.service_id FROM doctor_services ds JOIN services s ON s.id = ds.service_id
		WHERE ds.doctor_id = ? AND s.department_id <> ? ORDER BY ds.service_id`, doctorID, departmentID)
	if err != nil {
		return nil, err
	}
	removed := []int64{}
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return nil, err
		}
		removed = append(removed, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	for _, id := range removed {
		if _, err := q.ExecContext(ctx,
			`DELETE FROM doctor_services WHERE doctor_id = ? AND service_id = ?`, doctorID, id); err != nil {
			return nil, err
		}
	}
	return removed, nil
}

// SetInstitutionActive, kurumun aktiflik durumunu değiştirir.
func SetInstitutionActive(ctx context.Context, q DBTX, id int64, active bool) error {
	_, err := q.ExecContext(ctx, `UPDATE institutions SET is_active = ? WHERE id = ?`, active, id)
	return err
}

// InstitutionAdminOf, kurumun yöneticisini (ilk kayıtlı) döndürür.
func InstitutionAdminOf(ctx context.Context, q DBTX, institutionID int64) (User, error) {
	var userID int64
	err := q.QueryRowContext(ctx,
		`SELECT user_id FROM institution_admins WHERE institution_id = ? ORDER BY user_id LIMIT 1`, institutionID).Scan(&userID)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, ErrNotFound
	}
	if err != nil {
		return User{}, err
	}
	return UserByID(ctx, q, userID)
}
