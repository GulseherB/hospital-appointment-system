package httpapi

import (
	"net/http"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/auth"
	"hospital/backend/internal/domain"
	"hospital/backend/internal/service"
)

// Server, HTTP katmanının bağımlılıklarını taşır.
type Server struct {
	tokens       *auth.Tokens
	auth         *service.AuthService
	institutions *service.InstitutionService
	manage       *service.ManageService
	appointments *service.AppointmentService
}

// Services, sunucunun kullandığı servislerdir.
type Services struct {
	Auth         *service.AuthService
	Institutions *service.InstitutionService
	Manage       *service.ManageService
	Appointments *service.AppointmentService
}

// NewServer, sunucuyu oluşturur.
func NewServer(tokens *auth.Tokens, s Services) *Server {
	return &Server{tokens: tokens, auth: s.Auth, institutions: s.Institutions, manage: s.Manage, appointments: s.Appointments}
}

// Rol kuralları (yetki tanımlarında okunabilirlik için).
var (
	onlyPatient          = authOptions{roles: []domain.Role{domain.RolePatient}}
	onlyDoctor           = authOptions{roles: []domain.Role{domain.RoleDoctor}}
	onlyInstitutionAdmin = authOptions{roles: []domain.Role{domain.RoleInstitutionAdmin}}
	onlySuperAdmin       = authOptions{roles: []domain.Role{domain.RoleSuperAdmin}}
	tempPasswordAllowed  = authOptions{allowTempPassword: true}
)

// Handler, tüm uç noktaları ve ara katmanları içeren kök işleyicidir.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	const p = "/api/v1"
	handle := func(pattern string, opts *authOptions, h http.HandlerFunc) {
		if opts != nil {
			h = s.requireAuth(*opts, h)
		}
		mux.HandleFunc(pattern, h)
	}

	handle("GET "+p+"/health", nil, func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// Kimlik ve kayıt
	handle("POST "+p+"/auth/register", nil, s.handleRegister)
	handle("POST "+p+"/auth/login", nil, s.handleLogin)
	handle("POST "+p+"/auth/change-password", &tempPasswordAllowed, s.handleChangePassword)
	handle("GET "+p+"/auth/me", &tempPasswordAllowed, s.handleMe)

	// Kurum başvurusu ve süper admin
	handle("POST "+p+"/institution-applications", nil, s.handleCreateApplication)
	handle("GET "+p+"/admin/applications", &onlySuperAdmin, s.handleListApplications)
	handle("POST "+p+"/admin/applications/{id}/approve", &onlySuperAdmin, s.handleApproveApplication)
	handle("POST "+p+"/admin/applications/{id}/reject", &onlySuperAdmin, s.handleRejectApplication)
	handle("GET "+p+"/admin/institutions", &onlySuperAdmin, s.handleAdminListInstitutions)
	handle("PATCH "+p+"/admin/institutions/{id}", &onlySuperAdmin, s.handleSetInstitutionActive)
	handle("POST "+p+"/admin/institutions/{id}/reset-admin-password", &onlySuperAdmin, s.handleResetAdminPassword)

	// Kurum yönetimi
	handle("GET "+p+"/manage/branches", &onlyInstitutionAdmin, s.handleListBranches)
	handle("POST "+p+"/manage/branches", &onlyInstitutionAdmin, s.handleCreateBranch)
	handle("PUT "+p+"/manage/branches/{id}", &onlyInstitutionAdmin, s.handleUpdateBranch)
	handle("PUT "+p+"/manage/departments/{id}", &onlyInstitutionAdmin, s.handleUpdateDepartment)
	handle("PUT "+p+"/manage/services/{id}", &onlyInstitutionAdmin, s.handleUpdateService)
	handle("PUT "+p+"/manage/doctors/{id}", &onlyInstitutionAdmin, s.handleUpdateDoctor)
	handle("POST "+p+"/manage/doctors/{id}/reset-password", &onlyInstitutionAdmin, s.handleResetDoctorPassword)
	handle("GET "+p+"/manage/branches/{id}/working-hours", &onlyInstitutionAdmin, s.handleGetWorkingHours)
	handle("PUT "+p+"/manage/branches/{id}/working-hours", &onlyInstitutionAdmin, s.handleSetWorkingHours)
	handle("GET "+p+"/manage/departments", &onlyInstitutionAdmin, s.handleListDepartments)
	handle("POST "+p+"/manage/departments", &onlyInstitutionAdmin, s.handleCreateDepartment)
	handle("GET "+p+"/manage/services", &onlyInstitutionAdmin, s.handleListServices)
	handle("POST "+p+"/manage/services", &onlyInstitutionAdmin, s.handleCreateService)
	handle("GET "+p+"/manage/doctors", &onlyInstitutionAdmin, s.handleListDoctors)
	handle("POST "+p+"/manage/doctors", &onlyInstitutionAdmin, s.handleCreateDoctor)
	handle("PUT "+p+"/manage/doctors/{id}/services", &onlyInstitutionAdmin, s.handleSetDoctorServices)
	handle("GET "+p+"/manage/doctors/{id}/availability", &onlyInstitutionAdmin, s.handleGetAvailability)
	handle("PUT "+p+"/manage/doctors/{id}/availability", &onlyInstitutionAdmin, s.handleSetAvailability)
	handle("GET "+p+"/manage/appointments", &onlyInstitutionAdmin, s.handleManageAppointments)
	handle("POST "+p+"/manage/appointments/{id}/cancel", &onlyInstitutionAdmin, s.handleAdminCancel)

	// Hasta: arama, randevu, bildirimler
	handle("GET "+p+"/institutions", &onlyPatient, s.handlePublicInstitutions)
	handle("GET "+p+"/institutions/{id}/branches", &onlyPatient, s.handlePublicBranches)
	handle("GET "+p+"/branches/{id}/departments", &onlyPatient, s.handlePublicDepartments)
	handle("GET "+p+"/services", &onlyPatient, s.handlePublicServices)
	handle("GET "+p+"/appointment-slots", &onlyPatient, s.handleSlots)
	handle("POST "+p+"/appointments", &onlyPatient, s.handleCreateAppointment)
	handle("GET "+p+"/my-appointments", &onlyPatient, s.handleMyAppointments)
	handle("POST "+p+"/appointments/{id}/cancel", &onlyPatient, s.handlePatientCancel)
	handle("GET "+p+"/my-notifications", &onlyPatient, s.handleMyNotifications)
	handle("POST "+p+"/my-notifications/read-all", &onlyPatient, s.handleReadAllNotifications)
	handle("POST "+p+"/my-notifications/{id}/read", &onlyPatient, s.handleReadNotification)

	// Doktor
	handle("GET "+p+"/doctor/appointments", &onlyDoctor, s.handleDoctorAppointments)
	handle("POST "+p+"/doctor/appointments/{id}/approve", &onlyDoctor, s.handleDoctorApprove)
	handle("POST "+p+"/doctor/appointments/{id}/reject", &onlyDoctor, s.handleDoctorReject)
	handle("POST "+p+"/doctor/appointments/{id}/cancel", &onlyDoctor, s.handleDoctorCancel)

	// Tanımsız yollar sözleşmedeki JSON hata biçimiyle döner.
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		writeError(w, r, apperr.NotFound("İstenen uç nokta bulunamadı."))
	})

	return recoverPanics(logRequests(cors(mux)))
}
