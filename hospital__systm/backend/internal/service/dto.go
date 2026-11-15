package service

import (
	"hospital/backend/internal/clock"
	"hospital/backend/internal/domain"
	"hospital/backend/internal/repository"
)

// Bu dosya API sözleşmesindeki "Yanıt nesneleri"nin JSON karşılıklarını içerir.

// InstitutionDTO, kurum yanıtı.
type InstitutionDTO struct {
	ID       int64                  `json:"id"`
	Name     string                 `json:"name"`
	Type     domain.InstitutionType `json:"type"`
	Address  string                 `json:"address"`
	Phone    string                 `json:"phone"`
	Email    string                 `json:"email"`
	IsActive bool                   `json:"is_active"`
}

func toInstitutionDTO(i repository.Institution) InstitutionDTO {
	return InstitutionDTO{ID: i.ID, Name: i.Name, Type: i.Type, Address: i.Address, Phone: i.Phone, Email: i.Email, IsActive: i.IsActive}
}

// ApplicationInstitution, başvurudaki kurum bilgileri.
type ApplicationInstitution struct {
	Name    string                 `json:"name"`
	Type    domain.InstitutionType `json:"type"`
	Address string                 `json:"address"`
	Phone   string                 `json:"phone"`
	Email   string                 `json:"email"`
}

// ApplicationAdmin, başvurudaki yönetici bilgileri (şifre yanıtta yer almaz).
type ApplicationAdmin struct {
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	Email     string `json:"email"`
	Phone     string `json:"phone"`
}

// ApplicationDTO, başvuru yanıtı.
type ApplicationDTO struct {
	ID            int64                    `json:"id"`
	Status        domain.ApplicationStatus `json:"status"`
	Institution   ApplicationInstitution   `json:"institution"`
	Admin         ApplicationAdmin         `json:"admin"`
	InstitutionID *int64                   `json:"institution_id"`
	CreatedAt     clock.DateTime           `json:"created_at"`
	DecidedAt     *clock.DateTime          `json:"decided_at"`
}

func toApplicationDTO(a repository.Application) ApplicationDTO {
	return ApplicationDTO{
		ID:     a.ID,
		Status: a.Status,
		Institution: ApplicationInstitution{
			Name: a.InstitutionName, Type: a.InstitutionType, Address: a.InstitutionAddress,
			Phone: a.InstitutionPhone, Email: a.InstitutionEmail,
		},
		Admin: ApplicationAdmin{
			FirstName: a.AdminFirstName, LastName: a.AdminLastName, Email: a.AdminEmail, Phone: a.AdminPhone,
		},
		InstitutionID: a.InstitutionID,
		CreatedAt:     clock.DateTime(a.CreatedAt),
		DecidedAt:     clock.NullableDateTime(a.DecidedAt),
	}
}

// BranchDTO, şube yanıtı.
type BranchDTO struct {
	ID            int64  `json:"id"`
	InstitutionID int64  `json:"institution_id"`
	Name          string `json:"name"`
	Address       string `json:"address"`
	Phone         string `json:"phone"`
	IsActive      bool   `json:"is_active"`
}

func toBranchDTO(b repository.Branch) BranchDTO {
	return BranchDTO{ID: b.ID, InstitutionID: b.InstitutionID, Name: b.Name, Address: b.Address, Phone: b.Phone, IsActive: b.IsActive}
}

// DepartmentDTO, bölüm yanıtı.
type DepartmentDTO struct {
	ID       int64  `json:"id"`
	BranchID int64  `json:"branch_id"`
	Name     string `json:"name"`
	IsActive bool   `json:"is_active"`
}

func toDepartmentDTO(d repository.Department) DepartmentDTO {
	return DepartmentDTO{ID: d.ID, BranchID: d.BranchID, Name: d.Name, IsActive: d.IsActive}
}

// ServiceDTO, hizmet yanıtı. Ücret metin olarak döner ("750.00").
type ServiceDTO struct {
	ID           int64  `json:"id"`
	DepartmentID int64  `json:"department_id"`
	Name         string `json:"name"`
	DurationMin  int    `json:"duration_min"`
	Price        string `json:"price"`
	IsActive     bool   `json:"is_active"`
}

func toServiceDTO(s repository.Service) ServiceDTO {
	return ServiceDTO{ID: s.ID, DepartmentID: s.DepartmentID, Name: s.Name, DurationMin: s.DurationMin, Price: s.Price, IsActive: s.IsActive}
}

// DoctorDTO, yönetim ekranındaki doktor yanıtı.
type DoctorDTO struct {
	ID           int64   `json:"id"`
	FirstName    string  `json:"first_name"`
	LastName     string  `json:"last_name"`
	Email        string  `json:"email"`
	Phone        string  `json:"phone"`
	BranchID     int64   `json:"branch_id"`
	DepartmentID int64   `json:"department_id"`
	Specialty    string  `json:"specialty"`
	IsActive     bool    `json:"is_active"`
	ServiceIDs   []int64 `json:"service_ids"`
}

func toDoctorDTO(d repository.Doctor) DoctorDTO {
	ids := d.ServiceIDs
	if ids == nil {
		ids = []int64{}
	}
	return DoctorDTO{
		ID: d.ID, FirstName: d.FirstName, LastName: d.LastName, Email: d.Email, Phone: d.Phone,
		BranchID: d.BranchID, DepartmentID: d.DepartmentID, Specialty: d.Specialty, IsActive: d.IsActive,
		ServiceIDs: ids,
	}
}

// CreatedDoctorDTO, doktor oluşturma yanıtı: geçici şifre yalnızca burada bir kez döner.
type CreatedDoctorDTO struct {
	DoctorDTO
	TemporaryPassword string `json:"temporary_password"`
}

// WorkingHoursItem, çalışma saati öğesi.
type WorkingHoursItem struct {
	Weekday  int    `json:"weekday"`
	OpensAt  string `json:"opens_at"`
	ClosesAt string `json:"closes_at"`
}

// AvailabilityItem, uygunluk öğesi.
type AvailabilityItem struct {
	Weekday   int    `json:"weekday"`
	StartTime string `json:"start_time"`
	EndTime   string `json:"end_time"`
}
