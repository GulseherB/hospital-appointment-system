package repository

import (
	"context"
	"database/sql"
	"errors"
	"strings"

	"hospital/backend/internal/clock"
)

// Branch, branches tablosundaki bir satırdır.
type Branch struct {
	ID            int64
	InstitutionID int64
	Name          string
	Address       string
	Phone         string
	IsActive      bool
}

// Department, departments tablosundaki bir satırdır. InstitutionID, şube üzerinden gelir.
type Department struct {
	ID            int64
	BranchID      int64
	InstitutionID int64
	Name          string
	IsActive      bool
}

// Service, services tablosundaki bir satırdır. Price db'den "750.00" biçiminde okunur.
type Service struct {
	ID            int64
	DepartmentID  int64
	BranchID      int64
	InstitutionID int64
	Name          string
	DurationMin   int
	Price         string
	IsActive      bool
}

// ---- Şubeler ----

const branchSelect = `SELECT id, institution_id, name, COALESCE(address, ''), COALESCE(phone, ''), is_active FROM branches`

func scanBranch(s scanner) (Branch, error) {
	var b Branch
	err := s.Scan(&b.ID, &b.InstitutionID, &b.Name, &b.Address, &b.Phone, &b.IsActive)
	return b, err
}

// ListBranches, kurumun şubelerini döndürür.
func ListBranches(ctx context.Context, q DBTX, institutionID int64, onlyActive bool) ([]Branch, error) {
	query := branchSelect + ` WHERE institution_id = ?`
	if onlyActive {
		query += ` AND is_active = TRUE`
	}
	rows, err := q.QueryContext(ctx, query+` ORDER BY name, id`, institutionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Branch
	for rows.Next() {
		b, err := scanBranch(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, b)
	}
	return list, rows.Err()
}

// BranchByID, şubeyi getirir.
func BranchByID(ctx context.Context, q DBTX, id int64) (Branch, error) {
	b, err := scanBranch(q.QueryRowContext(ctx, branchSelect+` WHERE id = ?`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return Branch{}, ErrNotFound
	}
	return b, err
}

// InsertBranch, şube ekler.
func InsertBranch(ctx context.Context, q DBTX, b Branch) (int64, error) {
	res, err := q.ExecContext(ctx,
		`INSERT INTO branches (institution_id, name, address, phone, is_active) VALUES (?, ?, ?, ?, TRUE)`,
		b.InstitutionID, b.Name, nullString(b.Address), nullString(b.Phone))
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// ---- Çalışma saatleri ve uygunluk ----

// WeeklyRange, haftanın bir günü için saat aralığıdır.
type WeeklyRange struct {
	Weekday int
	Start   clock.TimeOfDay
	End     clock.TimeOfDay
}

func scanRanges(rows *sql.Rows) ([]WeeklyRange, error) {
	defer rows.Close()
	var list []WeeklyRange
	for rows.Next() {
		var r WeeklyRange
		var start, end string
		if err := rows.Scan(&r.Weekday, &start, &end); err != nil {
			return nil, err
		}
		var err error
		if r.Start, err = clock.ParseTimeOfDay(start); err != nil {
			return nil, err
		}
		if r.End, err = clock.ParseTimeOfDay(end); err != nil {
			return nil, err
		}
		list = append(list, r)
	}
	return list, rows.Err()
}

// WorkingHoursOf, şubenin haftalık çalışma saatlerini döndürür.
func WorkingHoursOf(ctx context.Context, q DBTX, branchID int64) ([]WeeklyRange, error) {
	rows, err := q.QueryContext(ctx,
		`SELECT weekday, opens_at, closes_at FROM working_hours WHERE branch_id = ? ORDER BY weekday`, branchID)
	if err != nil {
		return nil, err
	}
	return scanRanges(rows)
}

// ReplaceWorkingHours, şubenin tüm çalışma saatlerini değiştirir.
func ReplaceWorkingHours(ctx context.Context, q DBTX, branchID int64, items []WeeklyRange) error {
	if _, err := q.ExecContext(ctx, `DELETE FROM working_hours WHERE branch_id = ?`, branchID); err != nil {
		return err
	}
	for _, r := range items {
		if _, err := q.ExecContext(ctx,
			`INSERT INTO working_hours (branch_id, weekday, opens_at, closes_at) VALUES (?, ?, ?, ?)`,
			branchID, r.Weekday, r.Start.SQL(), r.End.SQL()); err != nil {
			return err
		}
	}
	return nil
}

// AvailabilityOf, doktorun haftalık uygunluk dilimlerini döndürür.
func AvailabilityOf(ctx context.Context, q DBTX, doctorID int64) ([]WeeklyRange, error) {
	rows, err := q.QueryContext(ctx,
		`SELECT weekday, start_time, end_time FROM availabilities WHERE doctor_id = ? ORDER BY weekday, start_time`, doctorID)
	if err != nil {
		return nil, err
	}
	return scanRanges(rows)
}

// AvailabilityOfBranchDoctors, şubedeki tüm doktorların uygunluklarını doktor id'sine göre döndürür.
func AvailabilityOfBranchDoctors(ctx context.Context, q DBTX, branchID int64) (map[int64][]WeeklyRange, error) {
	rows, err := q.QueryContext(ctx, `
		SELECT a.doctor_id, a.weekday, a.start_time, a.end_time
		FROM availabilities a JOIN doctors d ON d.user_id = a.doctor_id
		WHERE d.branch_id = ?`, branchID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := map[int64][]WeeklyRange{}
	for rows.Next() {
		var doctorID int64
		var r WeeklyRange
		var start, end string
		if err := rows.Scan(&doctorID, &r.Weekday, &start, &end); err != nil {
			return nil, err
		}
		if r.Start, err = clock.ParseTimeOfDay(start); err != nil {
			return nil, err
		}
		if r.End, err = clock.ParseTimeOfDay(end); err != nil {
			return nil, err
		}
		result[doctorID] = append(result[doctorID], r)
	}
	return result, rows.Err()
}

// ReplaceAvailability, doktorun tüm uygunluk dilimlerini değiştirir.
func ReplaceAvailability(ctx context.Context, q DBTX, doctorID int64, items []WeeklyRange) error {
	if _, err := q.ExecContext(ctx, `DELETE FROM availabilities WHERE doctor_id = ?`, doctorID); err != nil {
		return err
	}
	for _, r := range items {
		if _, err := q.ExecContext(ctx,
			`INSERT INTO availabilities (doctor_id, weekday, start_time, end_time) VALUES (?, ?, ?, ?)`,
			doctorID, r.Weekday, r.Start.SQL(), r.End.SQL()); err != nil {
			return err
		}
	}
	return nil
}

// ---- Bölümler ----

const departmentSelect = `
SELECT d.id, d.branch_id, b.institution_id, d.name, d.is_active
FROM departments d JOIN branches b ON b.id = d.branch_id`

func scanDepartment(s scanner) (Department, error) {
	var d Department
	err := s.Scan(&d.ID, &d.BranchID, &d.InstitutionID, &d.Name, &d.IsActive)
	return d, err
}

// ListDepartments, kurumun bölümlerini döndürür; branchID > 0 ise o şubeninkileri.
func ListDepartments(ctx context.Context, q DBTX, institutionID, branchID int64, onlyActive bool) ([]Department, error) {
	query := departmentSelect + ` WHERE b.institution_id = ?`
	args := []any{institutionID}
	if branchID > 0 {
		query += ` AND d.branch_id = ?`
		args = append(args, branchID)
	}
	if onlyActive {
		query += ` AND d.is_active = TRUE AND b.is_active = TRUE`
	}
	rows, err := q.QueryContext(ctx, query+` ORDER BY d.name, d.id`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Department
	for rows.Next() {
		d, err := scanDepartment(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, d)
	}
	return list, rows.Err()
}

// DepartmentByID, bölümü getirir.
func DepartmentByID(ctx context.Context, q DBTX, id int64) (Department, error) {
	d, err := scanDepartment(q.QueryRowContext(ctx, departmentSelect+` WHERE d.id = ?`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return Department{}, ErrNotFound
	}
	return d, err
}

// InsertDepartment, bölüm ekler.
func InsertDepartment(ctx context.Context, q DBTX, branchID int64, name string) (int64, error) {
	res, err := q.ExecContext(ctx, `INSERT INTO departments (branch_id, name, is_active) VALUES (?, ?, TRUE)`, branchID, name)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// ---- Hizmetler ----

const serviceSelect = `
SELECT s.id, s.department_id, d.branch_id, b.institution_id, s.name, s.duration_min, s.price, s.is_active
FROM services s JOIN departments d ON d.id = s.department_id JOIN branches b ON b.id = d.branch_id`

func scanService(s scanner) (Service, error) {
	var sv Service
	err := s.Scan(&sv.ID, &sv.DepartmentID, &sv.BranchID, &sv.InstitutionID, &sv.Name, &sv.DurationMin, &sv.Price, &sv.IsActive)
	return sv, err
}

// ServiceFilter, hizmet listesi filtresidir.
type ServiceFilter struct {
	InstitutionID int64
	DepartmentID  int64
	OnlyActive    bool // hizmet ve tüm üst kayıtlar (bölüm, şube, kurum) aktif olmalı
}

// ListServices, filtreye uyan hizmetleri döndürür.
func ListServices(ctx context.Context, q DBTX, f ServiceFilter) ([]Service, error) {
	var where []string
	var args []any
	if f.InstitutionID > 0 {
		where = append(where, `b.institution_id = ?`)
		args = append(args, f.InstitutionID)
	}
	if f.DepartmentID > 0 {
		where = append(where, `s.department_id = ?`)
		args = append(args, f.DepartmentID)
	}
	query := serviceSelect
	if f.OnlyActive {
		query += ` JOIN institutions i ON i.id = b.institution_id`
		where = append(where, `s.is_active = TRUE AND d.is_active = TRUE AND b.is_active = TRUE AND i.is_active = TRUE`)
	}
	if len(where) > 0 {
		query += ` WHERE ` + strings.Join(where, ` AND `)
	}
	rows, err := q.QueryContext(ctx, query+` ORDER BY s.name, s.id`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Service
	for rows.Next() {
		sv, err := scanService(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, sv)
	}
	return list, rows.Err()
}

// ServiceByID, hizmeti getirir.
func ServiceByID(ctx context.Context, q DBTX, id int64) (Service, error) {
	sv, err := scanService(q.QueryRowContext(ctx, serviceSelect+` WHERE s.id = ?`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return Service{}, ErrNotFound
	}
	return sv, err
}

// ServiceIsBookable, hizmet ve tüm üst kayıtları (bölüm, şube, kurum) aktif mi.
// lock true ise zincirdeki satırlar paylaşımlı kilitlenir (randevu oluşturma ile pasifleştirme sıraya girer).
func ServiceIsBookable(ctx context.Context, q DBTX, id int64, lock bool) (bool, error) {
	query := `
		SELECT s.is_active AND d.is_active AND b.is_active AND i.is_active FROM services s
		JOIN departments d ON d.id = s.department_id
		JOIN branches b ON b.id = d.branch_id
		JOIN institutions i ON i.id = b.institution_id
		WHERE s.id = ?`
	if lock {
		query += ` FOR SHARE`
	}
	var ok bool
	err := q.QueryRowContext(ctx, query, id).Scan(&ok)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return ok, err
}

// ActiveDoctorsForService, hizmeti veren aktif doktorları döndürür (yalnızca hizmetin bölümündeki doktorlar).
func ActiveDoctorsForService(ctx context.Context, q DBTX, serviceID int64) ([]Doctor, error) {
	rows, err := q.QueryContext(ctx, doctorSelect+`
		JOIN doctor_services ds ON ds.doctor_id = d.user_id
		JOIN services s ON s.id = ds.service_id
		WHERE ds.service_id = ? AND d.is_active = TRUE AND d.department_id = s.department_id
		ORDER BY u.first_name, u.last_name, u.id`, serviceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Doctor
	for rows.Next() {
		d, err := scanDoctor(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, d)
	}
	return list, rows.Err()
}

// InsertService, hizmet ekler.
func InsertService(ctx context.Context, q DBTX, departmentID int64, name string, durationMin int, price string) (int64, error) {
	res, err := q.ExecContext(ctx,
		`INSERT INTO services (department_id, name, duration_min, price, is_active) VALUES (?, ?, ?, ?, TRUE)`,
		departmentID, name, durationMin, price)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// ---- Doktorlar ----

// Doctor, doktor ve kullanıcı bilgilerinin birleşimidir.
type Doctor struct {
	ID            int64
	FirstName     string
	LastName      string
	Email         string
	Phone         string
	BranchID      int64
	DepartmentID  int64
	InstitutionID int64
	Specialty     string
	IsActive      bool
	ServiceIDs    []int64
}

const doctorSelect = `
SELECT u.id, u.first_name, u.last_name, u.email, COALESCE(u.phone, ''), d.branch_id, d.department_id,
       b.institution_id, d.specialty, d.is_active
FROM doctors d JOIN users u ON u.id = d.user_id JOIN branches b ON b.id = d.branch_id`

func scanDoctor(s scanner) (Doctor, error) {
	var d Doctor
	err := s.Scan(&d.ID, &d.FirstName, &d.LastName, &d.Email, &d.Phone, &d.BranchID, &d.DepartmentID,
		&d.InstitutionID, &d.Specialty, &d.IsActive)
	return d, err
}

// DoctorFilter, doktor listesi filtresidir.
type DoctorFilter struct {
	InstitutionID int64
	BranchID      int64
	DepartmentID  int64
}

// ListDoctors, filtreye uyan doktorları hizmet id'leriyle birlikte döndürür.
func ListDoctors(ctx context.Context, q DBTX, f DoctorFilter) ([]Doctor, error) {
	query := doctorSelect + ` WHERE b.institution_id = ?`
	args := []any{f.InstitutionID}
	if f.BranchID > 0 {
		query += ` AND d.branch_id = ?`
		args = append(args, f.BranchID)
	}
	if f.DepartmentID > 0 {
		query += ` AND d.department_id = ?`
		args = append(args, f.DepartmentID)
	}
	rows, err := q.QueryContext(ctx, query+` ORDER BY u.first_name, u.last_name, u.id`, args...)
	if err != nil {
		return nil, err
	}
	var list []Doctor
	for rows.Next() {
		d, err := scanDoctor(rows)
		if err != nil {
			rows.Close()
			return nil, err
		}
		list = append(list, d)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	for i := range list {
		if list[i].ServiceIDs, err = DoctorServiceIDs(ctx, q, list[i].ID); err != nil {
			return nil, err
		}
	}
	return list, nil
}

// DoctorByID, doktoru hizmet id'leriyle getirir. forUpdate true ise doktor satırı kilitlenir.
func DoctorByID(ctx context.Context, q DBTX, id int64, forUpdate bool) (Doctor, error) {
	query := doctorSelect + ` WHERE d.user_id = ?`
	if forUpdate {
		query += ` FOR UPDATE OF d` // yalnızca doktor satırı kilitlenir
	}
	d, err := scanDoctor(q.QueryRowContext(ctx, query, id))
	if errors.Is(err, sql.ErrNoRows) {
		return Doctor{}, ErrNotFound
	}
	if err != nil {
		return Doctor{}, err
	}
	d.ServiceIDs, err = DoctorServiceIDs(ctx, q, id)
	return d, err
}

// InsertDoctor, doctors tablosuna satır ekler (kullanıcı önceden eklenmiş olmalı).
func InsertDoctor(ctx context.Context, q DBTX, d Doctor) error {
	_, err := q.ExecContext(ctx,
		`INSERT INTO doctors (user_id, branch_id, department_id, specialty, is_active) VALUES (?, ?, ?, ?, TRUE)`,
		d.ID, d.BranchID, d.DepartmentID, d.Specialty)
	return err
}

// DoctorServiceIDs, doktorun verdiği hizmetlerin id'leri.
func DoctorServiceIDs(ctx context.Context, q DBTX, doctorID int64) ([]int64, error) {
	rows, err := q.QueryContext(ctx,
		`SELECT service_id FROM doctor_services WHERE doctor_id = ? ORDER BY service_id`, doctorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	ids := []int64{}
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// ReplaceDoctorServices, doktorun hizmet listesini değiştirir.
func ReplaceDoctorServices(ctx context.Context, q DBTX, doctorID int64, serviceIDs []int64) error {
	if _, err := q.ExecContext(ctx, `DELETE FROM doctor_services WHERE doctor_id = ?`, doctorID); err != nil {
		return err
	}
	for _, id := range serviceIDs {
		if _, err := q.ExecContext(ctx,
			`INSERT INTO doctor_services (doctor_id, service_id) VALUES (?, ?)`, doctorID, id); err != nil {
			return err
		}
	}
	return nil
}
