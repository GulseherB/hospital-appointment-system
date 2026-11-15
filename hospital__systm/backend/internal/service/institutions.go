package service

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/domain"
	"hospital/backend/internal/repository"
	"hospital/backend/internal/security"
	"hospital/backend/internal/validate"
)

// InstitutionService, kurum başvurusu ve süper admin işlemlerini yürütür.
type InstitutionService struct {
	db  *sql.DB
	now func() time.Time
}

// NewInstitutionService, servisi oluşturur.
func NewInstitutionService(db *sql.DB, now func() time.Time) *InstitutionService {
	return &InstitutionService{db: db, now: now}
}

// ApplicationInput, başvuru isteğidir.
type ApplicationInput struct {
	Institution struct {
		Name    string `json:"name"`
		Type    string `json:"type"`
		Address string `json:"address"`
		Phone   string `json:"phone"`
		Email   string `json:"email"`
	} `json:"institution"`
	Admin struct {
		FirstName string `json:"first_name"`
		LastName  string `json:"last_name"`
		Email     string `json:"email"`
		Phone     string `json:"phone"`
		Password  string `json:"password"`
	} `json:"admin"`
}

// Apply, yeni kurum başvurusu oluşturur (durum pending).
func (s *InstitutionService) Apply(ctx context.Context, in ApplicationInput) (ApplicationDTO, error) {
	var v validate.Errors
	a := repository.Application{
		InstitutionName:    v.Text(in.Institution.Name, "Kurum adı", 200),
		InstitutionType:    domain.InstitutionType(v.OneOf(in.Institution.Type, []string{string(domain.InstitutionHospital), string(domain.InstitutionClinic)}, "Kurum türü hastane (hospital) veya klinik (clinic) olmalıdır.")),
		InstitutionAddress: v.Text(in.Institution.Address, "Kurum adresi", 500),
		InstitutionPhone:   v.Phone(in.Institution.Phone, "Kurum telefonu"),
		InstitutionEmail:   v.Email(in.Institution.Email, "Kurum e-postası"),
		AdminFirstName:     v.Text(in.Admin.FirstName, "Yönetici adı", 100),
		AdminLastName:      v.Text(in.Admin.LastName, "Yönetici soyadı", 100),
		AdminEmail:         v.Email(in.Admin.Email, "Yönetici e-postası"),
		AdminPhone:         v.Phone(in.Admin.Phone, "Yönetici telefonu"),
	}
	password := v.Password(in.Admin.Password, "Yönetici şifresi")
	if err := v.Err(); err != nil {
		return ApplicationDTO{}, err
	}
	hash, err := security.HashPassword(password)
	if err != nil {
		return ApplicationDTO{}, err
	}
	a.AdminPasswordHash = hash
	a.CreatedAt = s.now()
	a.Status = domain.ApplicationPending

	err = repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		used, err := repository.EmailInUse(ctx, tx, a.AdminEmail)
		if err != nil {
			return err
		}
		if used {
			return apperr.EmailExists()
		}
		a.ID, err = repository.InsertApplication(ctx, tx, a)
		return err
	})
	if err != nil {
		return ApplicationDTO{}, err
	}
	return toApplicationDTO(a), nil
}

// ListApplications, başvuruları döndürür. status boşsa hepsi.
func (s *InstitutionService) ListApplications(ctx context.Context, status string) ([]ApplicationDTO, error) {
	if status != "" {
		var v validate.Errors
		v.OneOf(status, []string{"pending", "approved", "rejected"}, "status pending, approved veya rejected olmalıdır.")
		if err := v.Err(); err != nil {
			return nil, err
		}
	}
	list, err := repository.ListApplications(ctx, s.db, status)
	if err != nil {
		return nil, err
	}
	out := make([]ApplicationDTO, 0, len(list))
	for _, a := range list {
		out = append(out, toApplicationDTO(a))
	}
	return out, nil
}

func lockPendingApplication(ctx context.Context, tx *sql.Tx, id int64) (repository.Application, error) {
	a, err := repository.ApplicationByID(ctx, tx, id, true)
	if errors.Is(err, repository.ErrNotFound) {
		return a, apperr.NotFound("Başvuru bulunamadı.")
	}
	if err != nil {
		return a, err
	}
	if a.Status != domain.ApplicationPending {
		return a, apperr.BusinessRule("Bu başvuru zaten karara bağlanmış.")
	}
	return a, nil
}

// Approve, başvuruyu onaylar: kurum, yönetici hesabı ve varsayılan saatli "Merkez" şubesi oluşturulur.
func (s *InstitutionService) Approve(ctx context.Context, id int64) (ApplicationDTO, error) {
	var result repository.Application
	err := repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		a, err := lockPendingApplication(ctx, tx, id)
		if err != nil {
			return err
		}
		if _, err := repository.UserByEmail(ctx, tx, a.AdminEmail); err == nil {
			return apperr.EmailExists()
		} else if !errors.Is(err, repository.ErrNotFound) {
			return err
		}

		now := s.now()
		institutionID, err := repository.InsertInstitution(ctx, tx, repository.Institution{
			Name: a.InstitutionName, Type: a.InstitutionType, Address: a.InstitutionAddress,
			Phone: a.InstitutionPhone, Email: a.InstitutionEmail,
		}, now)
		if err != nil {
			return err
		}
		userID, err := repository.InsertUser(ctx, tx, repository.NewUser{
			Role: domain.RoleInstitutionAdmin, FirstName: a.AdminFirstName, LastName: a.AdminLastName,
			Email: a.AdminEmail, Phone: a.AdminPhone, PasswordHash: a.AdminPasswordHash,
		}, now)
		if err != nil {
			return mapDuplicate(err)
		}
		if err := repository.InsertInstitutionAdmin(ctx, tx, userID, institutionID); err != nil {
			return err
		}
		branchID, err := repository.InsertBranch(ctx, tx, repository.Branch{InstitutionID: institutionID, Name: domain.MainBranchName})
		if err != nil {
			return err
		}
		var hours []repository.WeeklyRange
		for _, h := range domain.DefaultWorkingHours() {
			r, err := parseRanges([][3]string{{h.OpensAt, h.ClosesAt}}, []int{h.Weekday}, true)
			if err != nil {
				return err
			}
			hours = append(hours, r...)
		}
		if err := repository.ReplaceWorkingHours(ctx, tx, branchID, hours); err != nil {
			return err
		}
		if err := repository.DecideApplication(ctx, tx, id, domain.ApplicationApproved, &institutionID, now); err != nil {
			return err
		}
		a.Status, a.InstitutionID, a.DecidedAt = domain.ApplicationApproved, &institutionID, &now
		result = a
		return nil
	})
	if err != nil {
		return ApplicationDTO{}, err
	}
	return toApplicationDTO(result), nil
}

// Reject, başvuruyu reddeder (gerekçe yoktur).
func (s *InstitutionService) Reject(ctx context.Context, id int64) (ApplicationDTO, error) {
	var result repository.Application
	err := repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		a, err := lockPendingApplication(ctx, tx, id)
		if err != nil {
			return err
		}
		now := s.now()
		if err := repository.DecideApplication(ctx, tx, id, domain.ApplicationRejected, nil, now); err != nil {
			return err
		}
		a.Status, a.DecidedAt = domain.ApplicationRejected, &now
		result = a
		return nil
	})
	if err != nil {
		return ApplicationDTO{}, err
	}
	return toApplicationDTO(result), nil
}

// ListInstitutions, kurumları döndürür (süper admin için hepsi, hastalar için yalnızca aktifler).
func (s *InstitutionService) ListInstitutions(ctx context.Context, onlyActive bool) ([]InstitutionDTO, error) {
	list, err := repository.ListInstitutions(ctx, s.db, onlyActive)
	if err != nil {
		return nil, err
	}
	out := make([]InstitutionDTO, 0, len(list))
	for _, i := range list {
		out = append(out, toInstitutionDTO(i))
	}
	return out, nil
}
