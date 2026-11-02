package handlers

import (
	"errors"
	"net/http"

	"github.com/GulseherB/hospital-appointment-system/backend/middleware"
	"github.com/GulseherB/hospital-appointment-system/backend/models"
	"github.com/GulseherB/hospital-appointment-system/backend/services"
	"github.com/gin-gonic/gin"
)

type StaffHandler struct {
	staffService   *services.StaffService
	catalogService *services.CatalogService
}

func NewStaffHandler(staffService *services.StaffService, catalogService *services.CatalogService) *StaffHandler {
	return &StaffHandler{staffService: staffService, catalogService: catalogService}
}

// ── İstek Yapıları ────────────────────────────────────────────────────────────

type doctorRequest struct {
	FullName     string `json:"full_name"     binding:"required"`
	Email        string `json:"email"         binding:"required,email"`
	Password     string `json:"password"      binding:"required,min=8"`
	Phone        string `json:"phone"         binding:"required"`
	Specialty    string `json:"specialty"`
	HospitalID   uint   `json:"hospital_id"   binding:"required"`
	DepartmentID uint   `json:"department_id" binding:"required"`
}

type updateDoctorRequest struct {
	FullName     string `json:"full_name"     binding:"required"`
	Phone        string `json:"phone"         binding:"required"`
	Specialty    string `json:"specialty"`
	DepartmentID uint   `json:"department_id"`
}

type managerRequest struct {
	FullName   string `json:"full_name" binding:"required"`
	Email      string `json:"email"     binding:"required,email"`
	Password   string `json:"password"  binding:"required,min=8"`
	Phone      string `json:"phone"     binding:"required"`
	HospitalID uint   `json:"hospital_id" binding:"required"`
}

type workScheduleRequest struct {
	DayOfWeek  int    `json:"day_of_week"  binding:"required,min=1,max=7"`
	StartTime  string `json:"start_time"   binding:"required"`
	EndTime    string `json:"end_time"     binding:"required"`
	BreakStart string `json:"break_start"`
	BreakEnd   string `json:"break_end"`
}

// ── Profil ────────────────────────────────────────────────────────────────────

// GetMe giriş yapmış kullanıcının profilini döner (tüm roller).
func (h *StaffHandler) GetMe(c *gin.Context) {
	claims, ok := middleware.ClaimsFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}
	user, err := h.staffService.GetStaff(claims.UserID)
	if err != nil {
		respondItem(c, nil, err)
		return
	}
	c.JSON(http.StatusOK, user)
}

// ── Çalışan Yönetimi ──────────────────────────────────────────────────────────

// ListStaff bir hastanenin doktorlarını listeler (Manager).
func (h *StaffHandler) ListStaff(c *gin.Context) {
	claims, ok := middleware.ClaimsFromContext(c)
	if !ok || claims.HospitalID == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "hospital scope required"})
		return
	}
	items, err := h.staffService.ListByHospital(*claims.HospitalID)
	respondList(c, items, err)
}

// CreateDoctor yeni doktor oluşturur (Manager veya SuperAdmin).
func (h *StaffHandler) CreateDoctor(c *gin.Context) {
	var req doctorRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid doctor data: " + err.Error()})
		return
	}
	claims, _ := middleware.ClaimsFromContext(c)
	if claims != nil && claims.Role == models.RoleHospitalManager {
		if claims.HospitalID == nil || *claims.HospitalID != req.HospitalID {
			c.JSON(http.StatusForbidden, gin.H{"error": "hospital is outside your scope"})
			return
		}
	}
	user, err := h.staffService.Create(services.StaffInput{
		FullName:     req.FullName,
		Email:        req.Email,
		Password:     req.Password,
		Phone:        req.Phone,
		Specialty:    req.Specialty,
		HospitalID:   req.HospitalID,
		DepartmentID: req.DepartmentID,
		Role:         models.RoleDoctor,
	})
	if err != nil {
		status := http.StatusInternalServerError
		if errors.Is(err, services.ErrInvalidStaff) || errors.Is(err, services.ErrNotFound) {
			status = http.StatusBadRequest
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"user": user})
}

// UpdateDoctor çalışan bilgilerini günceller.
func (h *StaffHandler) UpdateDoctor(c *gin.Context) {
	doctorID, err := parseID(c.Param("staff_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid staff id"})
		return
	}
	claims, _ := middleware.ClaimsFromContext(c)
	if claims != nil && claims.Role == models.RoleHospitalManager {
		if !h.staffService.DoctorInHospital(*claims.HospitalID, doctorID) {
			c.JSON(http.StatusForbidden, gin.H{"error": "staff is outside your hospital scope"})
			return
		}
	}
	var req updateDoctorRequest
	if !bind(c, &req) {
		return
	}
	user, err := h.staffService.UpdateStaff(doctorID, req.FullName, req.Phone, req.Specialty, req.DepartmentID)
	respondItem(c, user, err)
}

// GetStaff çalışan detayını döner.
func (h *StaffHandler) GetStaff(c *gin.Context) {
	staffID, err := parseID(c.Param("staff_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid staff id"})
		return
	}
	user, err := h.staffService.GetStaff(staffID)
	respondItem(c, user, err)
}

// CreateHospitalManager hastane yöneticisi hesabı oluşturur (SuperAdmin).
func (h *StaffHandler) CreateHospitalManager(c *gin.Context) {
	var req managerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid manager data: " + err.Error()})
		return
	}
	user, err := h.staffService.CreateManager(req.FullName, req.Email, req.Password, req.Phone, req.HospitalID)
	if err != nil {
		status := http.StatusBadRequest
		if errors.Is(err, services.ErrNotFound) {
			status = http.StatusNotFound
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"user": user})
}

// ── Hizmet Atama ──────────────────────────────────────────────────────────────

// AssignService doktora hizmet atar.
func (h *StaffHandler) AssignService(c *gin.Context) {
	staffID, serviceID, err := routeIDs(c, "staff_id", "service_id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid ids"})
		return
	}
	claims, _ := middleware.ClaimsFromContext(c)
	if claims != nil && claims.Role == models.RoleHospitalManager {
		if claims.HospitalID == nil || !h.staffService.DoctorInHospital(*claims.HospitalID, staffID) ||
			!h.catalogService.HospitalOwnsService(*claims.HospitalID, serviceID) {
			c.JSON(http.StatusForbidden, gin.H{"error": "resource is outside your hospital scope"})
			return
		}
	}
	if err := h.staffService.AssignService(staffID, serviceID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

// RemoveService doktordan hizmet kaldırır.
func (h *StaffHandler) RemoveService(c *gin.Context) {
	staffID, serviceID, err := routeIDs(c, "staff_id", "service_id")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid ids"})
		return
	}
	if err := h.staffService.RemoveService(staffID, serviceID); err != nil {
		respondItem(c, nil, err)
		return
	}
	c.Status(http.StatusNoContent)
}

// ListDoctorServices doktorun sunduğu hizmetleri listeler.
func (h *StaffHandler) ListDoctorServices(c *gin.Context) {
	staffID, err := parseID(c.Param("staff_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid staff id"})
		return
	}
	items, err := h.staffService.ListDoctorServices(staffID)
	respondList(c, items, err)
}

// ── Mesai Programı ────────────────────────────────────────────────────────────

// GetWorkSchedule çalışanın mesai programını döner.
// Manager ve ilgili çalışan görüntüleyebilir (okuma).
func (h *StaffHandler) GetWorkSchedule(c *gin.Context) {
	staffID, err := parseID(c.Param("staff_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid staff id"})
		return
	}
	claims, _ := middleware.ClaimsFromContext(c)
	// Doktor yalnızca kendi mesaini görebilir
	if claims != nil && claims.Role == models.RoleDoctor && claims.UserID != staffID {
		c.JSON(http.StatusForbidden, gin.H{"error": "you can only view your own schedule"})
		return
	}
	items, err := h.staffService.ListWorkSchedule(staffID)
	respondList(c, items, err)
}

// SetWorkSchedule çalışana mesai tanımlar veya günceller (sadece Manager).
func (h *StaffHandler) SetWorkSchedule(c *gin.Context) {
	staffID, err := parseID(c.Param("staff_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid staff id"})
		return
	}
	claims, ok := middleware.ClaimsFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
		return
	}
	// Kapsam kontrolü
	if claims.Role == models.RoleHospitalManager {
		if claims.HospitalID == nil || !h.staffService.DoctorInHospital(*claims.HospitalID, staffID) {
			c.JSON(http.StatusForbidden, gin.H{"error": "staff is outside your hospital scope"})
			return
		}
	}
	var req workScheduleRequest
	if !bind(c, &req) {
		return
	}
	var hospitalID uint
	if claims.HospitalID != nil {
		hospitalID = *claims.HospitalID
	}
	item, err := h.staffService.AddWorkSchedule(
		staffID, hospitalID, req.DayOfWeek, req.StartTime, req.EndTime, req.BreakStart, req.BreakEnd,
	)
	respondCreated(c, item, err)
}

// DeleteWorkSchedule bir günün mesai kaydını siler (sadece Manager).
func (h *StaffHandler) DeleteWorkSchedule(c *gin.Context) {
	staffID, err := parseID(c.Param("staff_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid staff id"})
		return
	}
	claims, _ := middleware.ClaimsFromContext(c)
	if claims != nil && claims.Role == models.RoleHospitalManager {
		if claims.HospitalID == nil || !h.staffService.DoctorInHospital(*claims.HospitalID, staffID) {
			c.JSON(http.StatusForbidden, gin.H{"error": "staff is outside your hospital scope"})
			return
		}
	}
	var req struct {
		DayOfWeek int `json:"day_of_week" binding:"required,min=1,max=7"`
	}
	if !bind(c, &req) {
		return
	}
	if err := h.staffService.DeleteWorkSchedule(staffID, req.DayOfWeek); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}
