// seed komutu, süper admini ve isteğe bağlı demo verisini ekler.
// Tekrar çalıştırılması güvenlidir: mevcut kayıtlar atlanır.
//
//	go run ./cmd/seed          yalnızca süper admin
//	go run ./cmd/seed -demo    süper admin + demo kurum, doktor, hasta
//
// Demo verisi tamamen uydurmadır; gerçek kişi verisi içermez.
package main

import (
	"context"
	"database/sql"
	"errors"
	"flag"
	"fmt"
	"log"
	"time"

	"hospital/backend/internal/clock"
	"hospital/backend/internal/config"
	"hospital/backend/internal/db"
	"hospital/backend/internal/domain"
	"hospital/backend/internal/security"
)

// Demo hesap e-postaları (uydurma, .local alan adı).
const (
	demoAdminEmail   = "admin@demo.local"
	demoPatientEmail = "patient@demo.local"
)

type demoService struct {
	name        string
	durationMin int
	price       string
}

type demoPerson struct {
	firstName, lastName, email, phone, specialty string
}

type demoDepartment struct {
	name     string
	services []demoService
	doctor   demoPerson
}

func main() {
	demo := flag.Bool("demo", false, "demo kurum, doktor ve hasta verisini de ekler")
	flag.Parse()

	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	if err := cfg.ValidateDB(); err != nil {
		log.Fatal(err)
	}
	if err := cfg.ValidateSeed(*demo); err != nil {
		log.Fatal(err)
	}
	if err := security.ValidatePassword(cfg.SuperAdminPassword); err != nil {
		log.Fatalf("SUPER_ADMIN_PASSWORD: %v", err)
	}
	if *demo {
		if err := security.ValidatePassword(cfg.DemoPassword); err != nil {
			log.Fatalf("DEMO_PASSWORD: %v", err)
		}
	}

	conn, err := db.Open(cfg, false)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	ctx := context.Background()
	if err := inTx(ctx, conn, func(tx *sql.Tx) error { return seedSuperAdmin(ctx, tx, cfg) }); err != nil {
		log.Fatalf("süper admin eklenemedi: %v", err)
	}
	if *demo {
		if err := inTx(ctx, conn, func(tx *sql.Tx) error { return seedDemo(ctx, tx, cfg.DemoPassword) }); err != nil {
			log.Fatalf("demo verisi eklenemedi: %v", err)
		}
	}
}

func inTx(ctx context.Context, conn *sql.DB, fn func(*sql.Tx) error) error {
	tx, err := conn.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback()
		return err
	}
	return tx.Commit()
}

func emailExists(ctx context.Context, tx *sql.Tx, email string) (bool, error) {
	var id uint64
	err := tx.QueryRowContext(ctx, `SELECT id FROM users WHERE email = ?`, email).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func insertUser(ctx context.Context, tx *sql.Tx, role domain.Role, p demoPerson, password string, now time.Time) (int64, error) {
	hash, err := security.HashPassword(password)
	if err != nil {
		return 0, err
	}
	var phone any
	if p.phone != "" {
		phone = p.phone
	}
	res, err := tx.ExecContext(ctx,
		`INSERT INTO users (role, first_name, last_name, email, phone, password_hash, must_change_password, created_at)
		 VALUES (?, ?, ?, ?, ?, ?, FALSE, ?)`,
		role, p.firstName, p.lastName, p.email, phone, hash, now)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func seedSuperAdmin(ctx context.Context, tx *sql.Tx, cfg config.Config) error {
	exists, err := emailExists(ctx, tx, cfg.SuperAdminEmail)
	if err != nil {
		return err
	}
	if exists {
		fmt.Println("süper admin zaten var, atlandı:", cfg.SuperAdminEmail)
		return nil
	}
	admin := demoPerson{firstName: "Süper", lastName: "Admin", email: cfg.SuperAdminEmail}
	if _, err := insertUser(ctx, tx, domain.RoleSuperAdmin, admin, cfg.SuperAdminPassword, clock.Now()); err != nil {
		return err
	}
	fmt.Println("süper admin eklendi:", cfg.SuperAdminEmail)
	return nil
}

func demoDepartments() []demoDepartment {
	return []demoDepartment{
		{
			name: "Dahiliye",
			services: []demoService{
				{"Genel Muayene", 15, "750.00"},
				{"Detaylı Muayene", 30, "1200.00"},
			},
			doctor: demoPerson{"Ayşe", "Demir", "doctor1@demo.local", "05000000001", "İç Hastalıkları"},
		},
		{
			name: "Radyoloji",
			services: []demoService{
				{"Röntgen", 15, "600.00"},
				{"Ultrason", 30, "900.00"},
			},
			doctor: demoPerson{"Mehmet", "Kaya", "doctor2@demo.local", "05000000002", "Radyoloji"},
		},
	}
}

func seedDemo(ctx context.Context, tx *sql.Tx, password string) error {
	exists, err := emailExists(ctx, tx, demoAdminEmail)
	if err != nil {
		return err
	}
	if exists {
		fmt.Println("demo verisi zaten var, atlandı")
		return nil
	}
	now := clock.Now()

	const (
		instName    = "Demo Sağlık Kliniği"
		instAddress = "Örnek Mah. Deneme Cad. No:1, İstanbul"
		instPhone   = "02120000000"
		instEmail   = "info@demo.local"
	)
	admin := demoPerson{firstName: "Deniz", lastName: "Yılmaz", email: demoAdminEmail, phone: "05000000000"}

	// Kurum ve onaylanmış başvurusu.
	res, err := tx.ExecContext(ctx,
		`INSERT INTO institutions (name, type, address, phone, email, is_active, created_at)
		 VALUES (?, ?, ?, ?, ?, TRUE, ?)`,
		instName, domain.InstitutionClinic, instAddress, instPhone, instEmail, now)
	if err != nil {
		return err
	}
	institutionID, err := res.LastInsertId()
	if err != nil {
		return err
	}

	adminHash, err := security.HashPassword(password)
	if err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO institution_applications (institution_name, institution_type, institution_address,
		   institution_phone, institution_email, admin_first_name, admin_last_name, admin_email,
		   admin_phone, admin_password_hash, status, institution_id, created_at, decided_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		instName, domain.InstitutionClinic, instAddress, instPhone, instEmail,
		admin.firstName, admin.lastName, admin.email, admin.phone, adminHash,
		domain.ApplicationApproved, institutionID, now, now); err != nil {
		return err
	}

	adminID, err := insertUser(ctx, tx, domain.RoleInstitutionAdmin, admin, password, now)
	if err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO institution_admins (user_id, institution_id) VALUES (?, ?)`, adminID, institutionID); err != nil {
		return err
	}

	// Merkez şubesi ve varsayılan çalışma saatleri.
	res, err = tx.ExecContext(ctx,
		`INSERT INTO branches (institution_id, name, is_active) VALUES (?, ?, TRUE)`, institutionID, domain.MainBranchName)
	if err != nil {
		return err
	}
	branchID, err := res.LastInsertId()
	if err != nil {
		return err
	}
	for _, h := range domain.DefaultWorkingHours() {
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO working_hours (branch_id, weekday, opens_at, closes_at) VALUES (?, ?, ?, ?)`,
			branchID, h.Weekday, h.OpensAt, h.ClosesAt); err != nil {
			return err
		}
	}

	// Bölümler, hizmetler, doktorlar, doktor hizmetleri ve uygunluklar.
	for _, d := range demoDepartments() {
		res, err := tx.ExecContext(ctx,
			`INSERT INTO departments (branch_id, name, is_active) VALUES (?, ?, TRUE)`, branchID, d.name)
		if err != nil {
			return err
		}
		departmentID, err := res.LastInsertId()
		if err != nil {
			return err
		}

		doctorID, err := insertUser(ctx, tx, domain.RoleDoctor, d.doctor, password, now)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO doctors (user_id, branch_id, department_id, specialty, is_active) VALUES (?, ?, ?, ?, TRUE)`,
			doctorID, branchID, departmentID, d.doctor.specialty); err != nil {
			return err
		}

		for _, s := range d.services {
			res, err := tx.ExecContext(ctx,
				`INSERT INTO services (department_id, name, duration_min, price, is_active) VALUES (?, ?, ?, ?, TRUE)`,
				departmentID, s.name, s.durationMin, s.price)
			if err != nil {
				return err
			}
			serviceID, err := res.LastInsertId()
			if err != nil {
				return err
			}
			if _, err := tx.ExecContext(ctx,
				`INSERT INTO doctor_services (doctor_id, service_id) VALUES (?, ?)`, doctorID, serviceID); err != nil {
				return err
			}
		}

		// Uygunluk şube saatleriyle aynı: Pazartesi–Cuma 09:00–17:00 (öğle arası slot üretiminde kesilir).
		for _, h := range domain.DefaultWorkingHours() {
			if _, err := tx.ExecContext(ctx,
				`INSERT INTO availabilities (doctor_id, weekday, start_time, end_time) VALUES (?, ?, ?, ?)`,
				doctorID, h.Weekday, h.OpensAt, h.ClosesAt); err != nil {
				return err
			}
		}
	}

	// Demo hasta (uydurma TC).
	patient := demoPerson{firstName: "Ali", lastName: "Örnek", email: demoPatientEmail, phone: "05000000003"}
	patientID, err := insertUser(ctx, tx, domain.RolePatient, patient, password, now)
	if err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO patients (user_id, national_id) VALUES (?, ?)`, patientID, "10000000000"); err != nil {
		return err
	}

	fmt.Println("demo verisi eklendi: 1 kurum, 1 yönetici, 1 şube, 2 bölüm, 4 hizmet, 2 doktor, 1 hasta")
	fmt.Println("demo hesapları:", demoAdminEmail, "doctor1@demo.local", "doctor2@demo.local", demoPatientEmail, "(şifre: DEMO_PASSWORD)")
	return nil
}
