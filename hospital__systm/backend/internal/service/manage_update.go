package service

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/repository"
	"hospital/backend/internal/security"
	"hospital/backend/internal/validate"
)

// Bu dosya kayıt güncelleme, pasifleştirme ve şifre sıfırlama işlemlerini içerir (B5).
// Pasifleştirme kuralı: gelecekte bekleyen veya onaylı randevusu olan kayıt pasifleştirilemez.
// Her güncelleme işleminin ilk ifadesi ilgili satırın kilididir (bkz. repository.LockRow).

func requireIsActive(p *bool) (bool, error) {
	if p == nil {
		return false, apperr.InvalidRequest("is_active alanı zorunludur.")
	}
	return *p, nil
}

// checkNoFutureAppointments, kapsamda gelecekte aktif randevu varsa HAS_FUTURE_APPOINTMENTS döndürür.
func (s *ManageService) checkNoFutureAppointments(ctx context.Context, tx *sql.Tx, scope repository.FutureScope, what string) error {
	n, err := repository.FutureActiveAppointments(ctx, tx, scope, s.now())
	if err != nil {
		return err
	}
	if n > 0 {
		return apperr.HasFutureAppointments(fmt.Sprintf(
			"%s için ileri tarihli %d aktif randevu var. Önce bu randevular iptal edilmeli veya tamamlanmalıdır.", what, n))
	}
	return nil
}

// lockOwn, satırı kilitler; satır yoksa verilen NOT_FOUND mesajını döndürür.
func lockOwn(ctx context.Context, tx *sql.Tx, table string, id int64, notFound string) error {
	err := repository.LockRow(ctx, tx, table, id)
	if errors.Is(err, repository.ErrNotFound) {
		return apperr.NotFound(notFound)
	}
	return err
}

// ---- Şube ----

// BranchUpdateInput, şube güncelleme isteğidir.
type BranchUpdateInput struct {
	Name     string `json:"name"`
	Address  string `json:"address"`
	Phone    string `json:"phone"`
	IsActive *bool  `json:"is_active"`
}

// UpdateBranch, şubeyi günceller veya pasifleştirir.
func (s *ManageService) UpdateBranch(ctx context.Context, institutionID, id int64, in BranchUpdateInput) (BranchDTO, error) {
	var v validate.Errors
	name := v.Text(in.Name, "Şube adı", 200)
	address := v.OptionalText(in.Address, "Adres", 500)
	phone := v.OptionalPhone(in.Phone, "Telefon")
	if err := v.Err(); err != nil {
		return BranchDTO{}, err
	}
	active, err := requireIsActive(in.IsActive)
	if err != nil {
		return BranchDTO{}, err
	}
	var result repository.Branch
	err = repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		if err := lockOwn(ctx, tx, "branches", id, "Şube bulunamadı."); err != nil {
			return err
		}
		b, err := ownBranch(ctx, tx, institutionID, id)
		if err != nil {
			return err
		}
		if b.IsActive && !active {
			if err := s.checkNoFutureAppointments(ctx, tx, repository.FutureScope{BranchID: id}, "Bu şube"); err != nil {
				return err
			}
		}
		result = repository.Branch{ID: id, InstitutionID: b.InstitutionID, Name: name, Address: address, Phone: phone, IsActive: active}
		return nameConflict(repository.UpdateBranch(ctx, tx, result), "Bu adla bir şube zaten var.")
	})
	if err != nil {
		return BranchDTO{}, err
	}
	return toBranchDTO(result), nil
}

// ---- Bölüm ----

// DepartmentUpdateInput, bölüm güncelleme isteğidir.
type DepartmentUpdateInput struct {
	Name     string `json:"name"`
	IsActive *bool  `json:"is_active"`
}

// UpdateDepartment, bölümü günceller veya pasifleştirir. Yeniden aktifleştirmede şube aktif olmalıdır.
func (s *ManageService) UpdateDepartment(ctx context.Context, institutionID, id int64, in DepartmentUpdateInput) (DepartmentDTO, error) {
	var v validate.Errors
	name := v.Text(in.Name, "Bölüm adı", 200)
	if err := v.Err(); err != nil {
		return DepartmentDTO{}, err
	}
	active, err := requireIsActive(in.IsActive)
	if err != nil {
		return DepartmentDTO{}, err
	}
	var result DepartmentDTO
	err = repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		if err := lockOwn(ctx, tx, "departments", id, "Bölüm bulunamadı."); err != nil {
			return err
		}
		d, err := ownDepartment(ctx, tx, institutionID, id)
		if err != nil {
			return err
		}
		if d.IsActive && !active {
			if err := s.checkNoFutureAppointments(ctx, tx, repository.FutureScope{DepartmentID: id}, "Bu bölüm"); err != nil {
				return err
			}
		}
		if !d.IsActive && active {
			b, err := repository.BranchByID(ctx, tx, d.BranchID)
			if err != nil {
				return err
			}
			if !b.IsActive {
				return apperr.BusinessRule("Pasif şubedeki bölüm aktifleştirilemez; önce şubeyi aktifleştirin.")
			}
		}
		if err := nameConflict(repository.UpdateDepartment(ctx, tx, id, name, active), "Bu şubede aynı adlı bir bölüm zaten var."); err != nil {
			return err
		}
		result = DepartmentDTO{ID: id, BranchID: d.BranchID, Name: name, IsActive: active}
		return nil
	})
	return result, err
}

// ---- Hizmet ----

// ServiceUpdateInput, hizmet güncelleme isteğidir.
type ServiceUpdateInput struct {
	Name        string `json:"name"`
	DurationMin int    `json:"duration_min"`
	Price       string `json:"price"`
	IsActive    *bool  `json:"is_active"`
}

// UpdateService, hizmeti günceller veya pasifleştirir. Süre ve ücret değişikliği yalnızca yeni randevuları etkiler.
func (s *ManageService) UpdateService(ctx context.Context, institutionID, id int64, in ServiceUpdateInput) (ServiceDTO, error) {
	var v validate.Errors
	name := v.Text(in.Name, "Hizmet adı", 200)
	duration := v.DurationMin(in.DurationMin)
	price := v.Price(in.Price)
	if err := v.Err(); err != nil {
		return ServiceDTO{}, err
	}
	active, err := requireIsActive(in.IsActive)
	if err != nil {
		return ServiceDTO{}, err
	}
	var result repository.Service
	err = repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		if err := lockOwn(ctx, tx, "services", id, "Hizmet bulunamadı."); err != nil {
			return err
		}
		sv, err := repository.ServiceByID(ctx, tx, id)
		if errors.Is(err, repository.ErrNotFound) || (err == nil && sv.InstitutionID != institutionID) {
			return apperr.NotFound("Hizmet bulunamadı.")
		}
		if err != nil {
			return err
		}
		if sv.IsActive && !active {
			if err := s.checkNoFutureAppointments(ctx, tx, repository.FutureScope{ServiceID: id}, "Bu hizmet"); err != nil {
				return err
			}
		}
		if !sv.IsActive && active {
			d, err := repository.DepartmentByID(ctx, tx, sv.DepartmentID)
			if err != nil {
				return err
			}
			if !d.IsActive {
				return apperr.BusinessRule("Pasif bölümdeki hizmet aktifleştirilemez; önce bölümü aktifleştirin.")
			}
		}
		if err := nameConflict(repository.UpdateService(ctx, tx, id, name, duration, price, active), "Bu bölümde aynı adlı bir hizmet zaten var."); err != nil {
			return err
		}
		result, err = repository.ServiceByID(ctx, tx, id)
		return err
	})
	if err != nil {
		return ServiceDTO{}, err
	}
	return toServiceDTO(result), nil
}

// ---- Doktor ----

// DoctorUpdateInput, doktor güncelleme isteğidir (e-posta değiştirilemez).
type DoctorUpdateInput struct {
	FirstName    string `json:"first_name"`
	LastName     string `json:"last_name"`
	Phone        string `json:"phone"`
	Specialty    string `json:"specialty"`
	BranchID     int64  `json:"branch_id"`
	DepartmentID int64  `json:"department_id"`
	IsActive     *bool  `json:"is_active"`
}

// DoctorUpdateDTO, doktor güncelleme yanıtıdır: bölüm değişince kaldırılan hizmetler ve
// şube değişince yeni şubenin saatlerine uymadığı için silinen uygunluk bildirilir.
type DoctorUpdateDTO struct {
	DoctorDTO
	RemovedServiceIDs   []int64 `json:"removed_service_ids"`
	AvailabilityCleared bool    `json:"availability_cleared"`
}

// UpdateDoctor, doktoru günceller, taşır veya pasifleştirir.
// Gelecekte aktif randevusu olan doktor pasifleştirilemez ve başka şube/bölüme taşınamaz.
func (s *ManageService) UpdateDoctor(ctx context.Context, institutionID, id int64, in DoctorUpdateInput) (DoctorUpdateDTO, error) {
	var v validate.Errors
	v.ID(in.BranchID, "Şube")
	v.ID(in.DepartmentID, "Bölüm")
	firstName := v.Text(in.FirstName, "Ad", 100)
	lastName := v.Text(in.LastName, "Soyad", 100)
	phone := v.Phone(in.Phone, "Telefon")
	specialty := v.OptionalText(in.Specialty, "Uzmanlık", 200)
	if err := v.Err(); err != nil {
		return DoctorUpdateDTO{}, err
	}
	active, err := requireIsActive(in.IsActive)
	if err != nil {
		return DoctorUpdateDTO{}, err
	}

	out := DoctorUpdateDTO{RemovedServiceIDs: []int64{}}
	err = repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		// Doktor satırı kilidi ilk ifadedir; randevu oluşturma da aynı satırı kilitler.
		d, err := ownDoctor(ctx, tx, institutionID, id, true)
		if err != nil {
			return err
		}
		b, err := ownBranch(ctx, tx, institutionID, in.BranchID)
		if err != nil {
			return err
		}
		dep, err := ownDepartment(ctx, tx, institutionID, in.DepartmentID)
		if err != nil {
			return err
		}
		if dep.BranchID != b.ID {
			return apperr.BusinessRule("Seçilen bölüm bu şubeye ait değil.")
		}

		branchChanged := b.ID != d.BranchID
		moving := branchChanged || dep.ID != d.DepartmentID
		if (d.IsActive && !active) || moving {
			what := "Doktor"
			if moving {
				what = "Doktorun başka şube veya bölüme taşınması"
			}
			if err := s.checkNoFutureAppointments(ctx, tx, repository.FutureScope{DoctorID: id}, what); err != nil {
				return err
			}
		}
		if active && (moving || !d.IsActive) && (!b.IsActive || !dep.IsActive) {
			return apperr.BusinessRule("Doktor yalnızca aktif şube ve bölümde aktif olabilir.")
		}

		if dep.ID != d.DepartmentID {
			if out.RemovedServiceIDs, err = repository.RemoveDoctorServicesOutside(ctx, tx, id, dep.ID); err != nil {
				return err
			}
		}
		if branchChanged {
			avail, err := repository.AvailabilityOf(ctx, tx, id)
			if err != nil {
				return err
			}
			hours, err := repository.WorkingHoursOf(ctx, tx, b.ID)
			if err != nil {
				return err
			}
			if len(avail) > 0 && rangesWithin(avail, hours) != "" {
				if err := repository.ReplaceAvailability(ctx, tx, id, nil); err != nil {
					return err
				}
				out.AvailabilityCleared = true
			}
		}

		d.FirstName, d.LastName, d.Phone, d.Specialty = firstName, lastName, phone, specialty
		d.BranchID, d.DepartmentID, d.IsActive = b.ID, dep.ID, active
		if err := repository.UpdateDoctor(ctx, tx, d); err != nil {
			return err
		}
		updated, err := repository.DoctorByID(ctx, tx, id, false)
		if err != nil {
			return err
		}
		out.DoctorDTO = toDoctorDTO(updated)
		return nil
	})
	if err != nil {
		return DoctorUpdateDTO{}, err
	}
	return out, nil
}

// newTempPassword, rastgele geçici şifre ve özetini üretir.
func newTempPassword() (plain, hash string, err error) {
	if plain, err = security.GenerateTempPassword(); err != nil {
		return "", "", err
	}
	hash, err = security.HashPassword(plain)
	return plain, hash, err
}

// ResetDoctorPassword, doktora yeni geçici şifre atar; doktor ilk girişte değiştirmek zorundadır.
func (s *ManageService) ResetDoctorPassword(ctx context.Context, institutionID, id int64) (CreatedDoctorDTO, error) {
	d, err := ownDoctor(ctx, s.db, institutionID, id, false)
	if err != nil {
		return CreatedDoctorDTO{}, err
	}
	plain, hash, err := newTempPassword()
	if err != nil {
		return CreatedDoctorDTO{}, err
	}
	if err := repository.SetPassword(ctx, s.db, id, hash, true); err != nil {
		return CreatedDoctorDTO{}, err
	}
	return CreatedDoctorDTO{DoctorDTO: toDoctorDTO(d), TemporaryPassword: plain}, nil
}

// ---- Süper admin: kurum ----

// InstitutionActiveInput, kurum aktiflik isteğidir.
type InstitutionActiveInput struct {
	IsActive *bool `json:"is_active"`
}

// SetInstitutionActive, kurumu aktifleştirir veya pasifleştirir.
// Pasif kurum hastalara görünmez ve yeni randevu alamaz; mevcut randevular ve girişler etkilenmez.
func (s *InstitutionService) SetInstitutionActive(ctx context.Context, id int64, in InstitutionActiveInput) (InstitutionDTO, error) {
	active, err := requireIsActive(in.IsActive)
	if err != nil {
		return InstitutionDTO{}, err
	}
	var result repository.Institution
	err = repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		if err := lockOwn(ctx, tx, "institutions", id, "Kurum bulunamadı."); err != nil {
			return err
		}
		if err := repository.SetInstitutionActive(ctx, tx, id, active); err != nil {
			return err
		}
		result, err = repository.InstitutionByID(ctx, tx, id)
		return err
	})
	if err != nil {
		return InstitutionDTO{}, err
	}
	return toInstitutionDTO(result), nil
}

// AdminPasswordResetDTO, yönetici şifre sıfırlama yanıtıdır; geçici şifre yalnızca burada bir kez döner.
type AdminPasswordResetDTO struct {
	InstitutionID     int64  `json:"institution_id"`
	AdminFirstName    string `json:"admin_first_name"`
	AdminLastName     string `json:"admin_last_name"`
	AdminEmail        string `json:"admin_email"`
	TemporaryPassword string `json:"temporary_password"`
}

// ResetAdminPassword, kurum yöneticisine yeni geçici şifre atar; yönetici ilk girişte değiştirmek zorundadır.
func (s *InstitutionService) ResetAdminPassword(ctx context.Context, institutionID int64) (AdminPasswordResetDTO, error) {
	if _, err := repository.InstitutionByID(ctx, s.db, institutionID); errors.Is(err, repository.ErrNotFound) {
		return AdminPasswordResetDTO{}, apperr.NotFound("Kurum bulunamadı.")
	} else if err != nil {
		return AdminPasswordResetDTO{}, err
	}
	admin, err := repository.InstitutionAdminOf(ctx, s.db, institutionID)
	if errors.Is(err, repository.ErrNotFound) {
		return AdminPasswordResetDTO{}, apperr.NotFound("Kurumun yöneticisi bulunamadı.")
	}
	if err != nil {
		return AdminPasswordResetDTO{}, err
	}
	plain, hash, err := newTempPassword()
	if err != nil {
		return AdminPasswordResetDTO{}, err
	}
	if err := repository.SetPassword(ctx, s.db, admin.ID, hash, true); err != nil {
		return AdminPasswordResetDTO{}, err
	}
	return AdminPasswordResetDTO{
		InstitutionID: institutionID, AdminFirstName: admin.FirstName, AdminLastName: admin.LastName,
		AdminEmail: admin.Email, TemporaryPassword: plain,
	}, nil
}
