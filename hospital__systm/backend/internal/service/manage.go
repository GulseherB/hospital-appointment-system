package service

import (
	"context"
	"database/sql"
	"errors"
	"slices"
	"sort"
	"strings"
	"time"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/domain"
	"hospital/backend/internal/repository"
	"hospital/backend/internal/security"
	"hospital/backend/internal/validate"
)

// ManageService, kurum yöneticisinin kendi kurumundaki tanımlamalarını yürütür.
// Her işlemde kayıtların yöneticinin kurumuna ait olduğu denetlenir; değilse NOT_FOUND döner.
type ManageService struct {
	db  *sql.DB
	now func() time.Time
}

// NewManageService, servisi oluşturur.
func NewManageService(db *sql.DB, now func() time.Time) *ManageService {
	return &ManageService{db: db, now: now}
}

// ---- Sahiplik denetimleri ----

func ownBranch(ctx context.Context, q repository.DBTX, institutionID, id int64) (repository.Branch, error) {
	b, err := repository.BranchByID(ctx, q, id)
	if errors.Is(err, repository.ErrNotFound) || (err == nil && b.InstitutionID != institutionID) {
		return repository.Branch{}, apperr.NotFound("Şube bulunamadı.")
	}
	return b, err
}

func ownDepartment(ctx context.Context, q repository.DBTX, institutionID, id int64) (repository.Department, error) {
	d, err := repository.DepartmentByID(ctx, q, id)
	if errors.Is(err, repository.ErrNotFound) || (err == nil && d.InstitutionID != institutionID) {
		return repository.Department{}, apperr.NotFound("Bölüm bulunamadı.")
	}
	return d, err
}

func ownDoctor(ctx context.Context, q repository.DBTX, institutionID, id int64, forUpdate bool) (repository.Doctor, error) {
	d, err := repository.DoctorByID(ctx, q, id, forUpdate)
	if errors.Is(err, repository.ErrNotFound) || (err == nil && d.InstitutionID != institutionID) {
		return repository.Doctor{}, apperr.NotFound("Doktor bulunamadı.")
	}
	return d, err
}

// nameConflict, benzersiz ad ihlalini NAME_EXISTS hatasına çevirir.
func nameConflict(err error, message string) error {
	if key, ok := repository.DuplicateKey(err); ok && strings.Contains(key, "_name") {
		return apperr.NameExists(message)
	}
	return err
}

// ---- Şubeler ----

// BranchInput, şube oluşturma isteğidir.
type BranchInput struct {
	Name    string `json:"name"`
	Address string `json:"address"`
	Phone   string `json:"phone"`
}

// ListBranches, kurumun tüm şubeleri.
func (s *ManageService) ListBranches(ctx context.Context, institutionID int64) ([]BranchDTO, error) {
	list, err := repository.ListBranches(ctx, s.db, institutionID, false)
	if err != nil {
		return nil, err
	}
	out := make([]BranchDTO, 0, len(list))
	for _, b := range list {
		out = append(out, toBranchDTO(b))
	}
	return out, nil
}

// CreateBranch, şube ekler. Yeni şubenin çalışma saati yoktur.
func (s *ManageService) CreateBranch(ctx context.Context, institutionID int64, in BranchInput) (BranchDTO, error) {
	var v validate.Errors
	b := repository.Branch{
		InstitutionID: institutionID,
		Name:          v.Text(in.Name, "Şube adı", 200),
		Address:       v.OptionalText(in.Address, "Adres", 500),
		Phone:         v.OptionalPhone(in.Phone, "Telefon"),
		IsActive:      true,
	}
	if err := v.Err(); err != nil {
		return BranchDTO{}, err
	}
	id, err := repository.InsertBranch(ctx, s.db, b)
	if err != nil {
		return BranchDTO{}, nameConflict(err, "Bu adla bir şube zaten var.")
	}
	b.ID = id
	return toBranchDTO(b), nil
}

// ---- Çalışma saatleri ----

// WorkingHoursInput, çalışma saatleri isteğidir.
type WorkingHoursInput struct {
	Items []WorkingHoursItem `json:"items"`
}

// GetWorkingHours, şubenin çalışma saatleri.
func (s *ManageService) GetWorkingHours(ctx context.Context, institutionID, branchID int64) ([]WorkingHoursItem, error) {
	if _, err := ownBranch(ctx, s.db, institutionID, branchID); err != nil {
		return nil, err
	}
	hours, err := repository.WorkingHoursOf(ctx, s.db, branchID)
	if err != nil {
		return nil, err
	}
	return toWorkingHoursItems(hours), nil
}

// SetWorkingHours, şubenin tüm çalışma saatlerini değiştirir.
// Şubedeki bir doktorun uygunluğu yeni saatlerin dışında kalırsa reddedilir.
func (s *ManageService) SetWorkingHours(ctx context.Context, institutionID, branchID int64, in WorkingHoursInput) ([]WorkingHoursItem, error) {
	if in.Items == nil {
		return nil, apperr.InvalidRequest("items alanı zorunludur (kapalı şube için boş liste gönderin).")
	}
	raw := make([][3]string, len(in.Items))
	days := make([]int, len(in.Items))
	for i, it := range in.Items {
		raw[i], days[i] = [3]string{it.OpensAt, it.ClosesAt}, it.Weekday
	}
	hours, err := parseRanges(raw, days, true)
	if err != nil {
		return nil, err
	}

	err = repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		if _, err := ownBranch(ctx, tx, institutionID, branchID); err != nil {
			return err
		}
		byDoctor, err := repository.AvailabilityOfBranchDoctors(ctx, tx, branchID)
		if err != nil {
			return err
		}
		doctorIDs := make([]int64, 0, len(byDoctor))
		for id := range byDoctor {
			doctorIDs = append(doctorIDs, id)
		}
		sort.Slice(doctorIDs, func(i, j int) bool { return doctorIDs[i] < doctorIDs[j] })
		for _, id := range doctorIDs {
			if msg := rangesWithin(byDoctor[id], hours); msg != "" {
				d, err := repository.DoctorByID(ctx, tx, id, false)
				if err != nil {
					return err
				}
				return apperr.BusinessRule("Dr. " + d.FirstName + " " + d.LastName + " uygunluğu yeni saatlere uymuyor: " + msg + " Önce doktorun uygunluğunu güncelleyin.")
			}
		}
		return repository.ReplaceWorkingHours(ctx, tx, branchID, hours)
	})
	if err != nil {
		return nil, err
	}
	return toWorkingHoursItems(hours), nil
}

// ---- Bölümler ----

// DepartmentInput, bölüm oluşturma isteğidir.
type DepartmentInput struct {
	BranchID int64  `json:"branch_id"`
	Name     string `json:"name"`
}

// ListDepartments, kurumun bölümleri; branchID > 0 ise o şubenin.
func (s *ManageService) ListDepartments(ctx context.Context, institutionID, branchID int64) ([]DepartmentDTO, error) {
	if branchID > 0 {
		if _, err := ownBranch(ctx, s.db, institutionID, branchID); err != nil {
			return nil, err
		}
	}
	list, err := repository.ListDepartments(ctx, s.db, institutionID, branchID, false)
	if err != nil {
		return nil, err
	}
	out := make([]DepartmentDTO, 0, len(list))
	for _, d := range list {
		out = append(out, toDepartmentDTO(d))
	}
	return out, nil
}

// CreateDepartment, aktif bir şubeye bölüm ekler.
func (s *ManageService) CreateDepartment(ctx context.Context, institutionID int64, in DepartmentInput) (DepartmentDTO, error) {
	var v validate.Errors
	v.ID(in.BranchID, "Şube")
	name := v.Text(in.Name, "Bölüm adı", 200)
	if err := v.Err(); err != nil {
		return DepartmentDTO{}, err
	}
	b, err := ownBranch(ctx, s.db, institutionID, in.BranchID)
	if err != nil {
		return DepartmentDTO{}, err
	}
	if !b.IsActive {
		return DepartmentDTO{}, apperr.BusinessRule("Pasif şubeye bölüm eklenemez.")
	}
	id, err := repository.InsertDepartment(ctx, s.db, b.ID, name)
	if err != nil {
		return DepartmentDTO{}, nameConflict(err, "Bu şubede aynı adlı bir bölüm zaten var.")
	}
	return DepartmentDTO{ID: id, BranchID: b.ID, Name: name, IsActive: true}, nil
}

// ---- Hizmetler ----

// ServiceInput, hizmet oluşturma isteğidir.
type ServiceInput struct {
	DepartmentID int64  `json:"department_id"`
	Name         string `json:"name"`
	DurationMin  int    `json:"duration_min"`
	Price        string `json:"price"`
}

// ListServices, kurumun hizmetleri; departmentID > 0 ise o bölümün.
func (s *ManageService) ListServices(ctx context.Context, institutionID, departmentID int64) ([]ServiceDTO, error) {
	if departmentID > 0 {
		if _, err := ownDepartment(ctx, s.db, institutionID, departmentID); err != nil {
			return nil, err
		}
	}
	list, err := repository.ListServices(ctx, s.db, repository.ServiceFilter{InstitutionID: institutionID, DepartmentID: departmentID})
	if err != nil {
		return nil, err
	}
	out := make([]ServiceDTO, 0, len(list))
	for _, sv := range list {
		out = append(out, toServiceDTO(sv))
	}
	return out, nil
}

// CreateService, aktif bir bölüme hizmet ekler.
func (s *ManageService) CreateService(ctx context.Context, institutionID int64, in ServiceInput) (ServiceDTO, error) {
	var v validate.Errors
	v.ID(in.DepartmentID, "Bölüm")
	name := v.Text(in.Name, "Hizmet adı", 200)
	duration := v.DurationMin(in.DurationMin)
	price := v.Price(in.Price)
	if err := v.Err(); err != nil {
		return ServiceDTO{}, err
	}
	d, err := ownDepartment(ctx, s.db, institutionID, in.DepartmentID)
	if err != nil {
		return ServiceDTO{}, err
	}
	if !d.IsActive {
		return ServiceDTO{}, apperr.BusinessRule("Pasif bölüme hizmet eklenemez.")
	}
	id, err := repository.InsertService(ctx, s.db, d.ID, name, duration, price)
	if err != nil {
		return ServiceDTO{}, nameConflict(err, "Bu bölümde aynı adlı bir hizmet zaten var.")
	}
	sv, err := repository.ServiceByID(ctx, s.db, id)
	if err != nil {
		return ServiceDTO{}, err
	}
	return toServiceDTO(sv), nil
}

// ---- Doktorlar ----

// DoctorInput, doktor oluşturma isteğidir.
type DoctorInput struct {
	BranchID     int64  `json:"branch_id"`
	DepartmentID int64  `json:"department_id"`
	FirstName    string `json:"first_name"`
	LastName     string `json:"last_name"`
	Email        string `json:"email"`
	Phone        string `json:"phone"`
	Specialty    string `json:"specialty"`
}

// ListDoctors, kurumun doktorları (isteğe bağlı şube/bölüm filtresi).
func (s *ManageService) ListDoctors(ctx context.Context, institutionID, branchID, departmentID int64) ([]DoctorDTO, error) {
	list, err := repository.ListDoctors(ctx, s.db, repository.DoctorFilter{
		InstitutionID: institutionID, BranchID: branchID, DepartmentID: departmentID,
	})
	if err != nil {
		return nil, err
	}
	out := make([]DoctorDTO, 0, len(list))
	for _, d := range list {
		out = append(out, toDoctorDTO(d))
	}
	return out, nil
}

// CreateDoctor, doktor hesabı açar. Sistem rastgele geçici şifre üretir; yanıtta yalnızca bir kez döner.
func (s *ManageService) CreateDoctor(ctx context.Context, institutionID int64, in DoctorInput) (CreatedDoctorDTO, error) {
	var v validate.Errors
	v.ID(in.BranchID, "Şube")
	v.ID(in.DepartmentID, "Bölüm")
	d := repository.Doctor{
		BranchID:     in.BranchID,
		DepartmentID: in.DepartmentID,
		FirstName:    v.Text(in.FirstName, "Ad", 100),
		LastName:     v.Text(in.LastName, "Soyad", 100),
		Email:        v.Email(in.Email, "E-posta"),
		Phone:        v.Phone(in.Phone, "Telefon"),
		Specialty:    v.OptionalText(in.Specialty, "Uzmanlık", 200),
		IsActive:     true,
	}
	if err := v.Err(); err != nil {
		return CreatedDoctorDTO{}, err
	}

	tempPassword, err := security.GenerateTempPassword()
	if err != nil {
		return CreatedDoctorDTO{}, err
	}
	hash, err := security.HashPassword(tempPassword)
	if err != nil {
		return CreatedDoctorDTO{}, err
	}

	err = repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		b, err := ownBranch(ctx, tx, institutionID, d.BranchID)
		if err != nil {
			return err
		}
		if !b.IsActive {
			return apperr.BusinessRule("Pasif şubeye doktor eklenemez.")
		}
		dep, err := ownDepartment(ctx, tx, institutionID, d.DepartmentID)
		if err != nil {
			return err
		}
		if dep.BranchID != b.ID {
			return apperr.BusinessRule("Seçilen bölüm bu şubeye ait değil.")
		}
		if !dep.IsActive {
			return apperr.BusinessRule("Pasif bölüme doktor eklenemez.")
		}
		used, err := repository.EmailInUse(ctx, tx, d.Email)
		if err != nil {
			return err
		}
		if used {
			return apperr.EmailExists()
		}
		d.ID, err = repository.InsertUser(ctx, tx, repository.NewUser{
			Role: domain.RoleDoctor, FirstName: d.FirstName, LastName: d.LastName,
			Email: d.Email, Phone: d.Phone, PasswordHash: hash, MustChangePassword: true,
		}, s.now())
		if err != nil {
			return mapDuplicate(err)
		}
		return repository.InsertDoctor(ctx, tx, d)
	})
	if err != nil {
		return CreatedDoctorDTO{}, err
	}
	d.ServiceIDs = []int64{}
	return CreatedDoctorDTO{DoctorDTO: toDoctorDTO(d), TemporaryPassword: tempPassword}, nil
}

// DoctorServicesInput, doktorun hizmetleri isteğidir.
type DoctorServicesInput struct {
	ServiceIDs []int64 `json:"service_ids"`
}

// SetDoctorServices, doktorun verdiği hizmetleri değiştirir. Yalnızca doktorun bölümündeki hizmetler kabul edilir.
func (s *ManageService) SetDoctorServices(ctx context.Context, institutionID, doctorID int64, in DoctorServicesInput) (DoctorDTO, error) {
	if in.ServiceIDs == nil {
		return DoctorDTO{}, apperr.InvalidRequest("service_ids alanı zorunludur (boş liste olabilir).")
	}
	unique := make([]int64, 0, len(in.ServiceIDs))
	seen := map[int64]bool{}
	for _, id := range in.ServiceIDs {
		if id <= 0 {
			return DoctorDTO{}, apperr.InvalidRequest("Geçersiz hizmet kimliği.")
		}
		if !seen[id] {
			seen[id] = true
			unique = append(unique, id)
		}
	}

	var result repository.Doctor
	err := repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		d, err := ownDoctor(ctx, tx, institutionID, doctorID, true)
		if err != nil {
			return err
		}
		for _, id := range unique {
			sv, err := repository.ServiceByID(ctx, tx, id)
			if errors.Is(err, repository.ErrNotFound) || (err == nil && sv.InstitutionID != institutionID) {
				return apperr.NotFound("Hizmet bulunamadı.")
			}
			if err != nil {
				return err
			}
			if sv.DepartmentID != d.DepartmentID {
				return apperr.BusinessRule("\"" + sv.Name + "\" hizmeti doktorun bölümüne ait değil.")
			}
			// Pasif hizmet yeni atanamaz; pasifleştirmeden önce yapılmış atama korunabilir.
			if !sv.IsActive && !slices.Contains(d.ServiceIDs, sv.ID) {
				return apperr.BusinessRule("\"" + sv.Name + "\" hizmeti pasif; yeni atama yapılamaz.")
			}
		}
		if err := repository.ReplaceDoctorServices(ctx, tx, doctorID, unique); err != nil {
			return err
		}
		result, err = repository.DoctorByID(ctx, tx, doctorID, false)
		return err
	})
	if err != nil {
		return DoctorDTO{}, err
	}
	return toDoctorDTO(result), nil
}

// ---- Uygunluk ----

// AvailabilityInput, uygunluk isteğidir.
type AvailabilityInput struct {
	Items []AvailabilityItem `json:"items"`
}

// GetAvailability, doktorun uygunluk dilimleri.
func (s *ManageService) GetAvailability(ctx context.Context, institutionID, doctorID int64) ([]AvailabilityItem, error) {
	if _, err := ownDoctor(ctx, s.db, institutionID, doctorID, false); err != nil {
		return nil, err
	}
	ranges, err := repository.AvailabilityOf(ctx, s.db, doctorID)
	if err != nil {
		return nil, err
	}
	return toAvailabilityItems(ranges), nil
}

// SetAvailability, doktorun uygunluğunu değiştirir. Dilimler şubenin o günkü çalışma saatleri içinde olmalı ve çakışmamalıdır.
func (s *ManageService) SetAvailability(ctx context.Context, institutionID, doctorID int64, in AvailabilityInput) ([]AvailabilityItem, error) {
	if in.Items == nil {
		return nil, apperr.InvalidRequest("items alanı zorunludur (boş liste olabilir).")
	}
	raw := make([][3]string, len(in.Items))
	days := make([]int, len(in.Items))
	for i, it := range in.Items {
		raw[i], days[i] = [3]string{it.StartTime, it.EndTime}, it.Weekday
	}
	ranges, err := parseRanges(raw, days, false)
	if err != nil {
		return nil, err
	}

	err = repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		d, err := ownDoctor(ctx, tx, institutionID, doctorID, true)
		if err != nil {
			return err
		}
		hours, err := repository.WorkingHoursOf(ctx, tx, d.BranchID)
		if err != nil {
			return err
		}
		if msg := rangesWithin(ranges, hours); msg != "" {
			return apperr.BusinessRule(msg)
		}
		return repository.ReplaceAvailability(ctx, tx, doctorID, ranges)
	})
	if err != nil {
		return nil, err
	}
	return toAvailabilityItems(ranges), nil
}
