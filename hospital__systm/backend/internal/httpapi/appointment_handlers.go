package httpapi

import (
	"net/http"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/service"
)

// Hasta, doktor ve yöneticinin randevu uç noktaları. Kullanıcı ve kurum kimliği her zaman oturumdan alınır.

// withID, yoldaki {id} değerini okuyup işleyiciye verir; işleyicinin döndürdüğü nesneyi 200 ile yazar.
func withID[T any](fn func(r *http.Request, id int64) (T, error)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := pathID(r, "id")
		if err != nil {
			writeError(w, r, err)
			return
		}
		v, err := fn(r, id)
		if err != nil {
			writeError(w, r, err)
			return
		}
		writeJSON(w, http.StatusOK, v)
	}
}

// ---- Hasta: arama ----

func (s *Server) handlePublicInstitutions(w http.ResponseWriter, r *http.Request) {
	list, err := s.appointments.PublicInstitutions(r.Context())
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}

func (s *Server) handlePublicBranches(w http.ResponseWriter, r *http.Request) {
	withID(func(r *http.Request, id int64) (any, error) {
		list, err := s.appointments.PublicBranches(r.Context(), id)
		return listResponse(list), err
	})(w, r)
}

func (s *Server) handlePublicDepartments(w http.ResponseWriter, r *http.Request) {
	withID(func(r *http.Request, id int64) (any, error) {
		list, err := s.appointments.PublicDepartments(r.Context(), id)
		return listResponse(list), err
	})(w, r)
}

func (s *Server) handlePublicServices(w http.ResponseWriter, r *http.Request) {
	departmentID, err := queryID(r, "department_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	list, err := s.appointments.PublicServices(r.Context(), departmentID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}

// ---- Hasta: slot ve randevu ----

func (s *Server) handleSlots(w http.ResponseWriter, r *http.Request) {
	serviceID, err := queryID(r, "service_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	doctorID, err := queryID(r, "doctor_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	q := r.URL.Query()
	list, err := s.appointments.Slots(r.Context(), service.SlotQuery{
		ServiceID: serviceID, DoctorID: doctorID, DateFrom: q.Get("date_from"), DateTo: q.Get("date_to"),
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}

func (s *Server) handleCreateAppointment(w http.ResponseWriter, r *http.Request) {
	var in service.CreateAppointmentInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	a, err := s.appointments.CreateAppointment(r.Context(), currentUser(r).UserID, in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, a)
}

func (s *Server) handleMyAppointments(w http.ResponseWriter, r *http.Request) {
	list, err := s.appointments.MyAppointments(r.Context(), currentUser(r).UserID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}

func (s *Server) handlePatientCancel(w http.ResponseWriter, r *http.Request) {
	withID(func(r *http.Request, id int64) (service.AppointmentDTO, error) {
		return s.appointments.PatientCancel(r.Context(), currentUser(r).UserID, id)
	})(w, r)
}

// ---- Hasta: bildirimler ----

func (s *Server) handleMyNotifications(w http.ResponseWriter, r *http.Request) {
	var onlyUnread bool
	switch r.URL.Query().Get("unread") {
	case "", "false":
	case "true":
		onlyUnread = true
	default:
		writeError(w, r, apperr.InvalidRequest("unread değeri true veya false olmalıdır."))
		return
	}
	list, err := s.appointments.MyNotifications(r.Context(), currentUser(r).UserID, onlyUnread)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, list)
}

func (s *Server) handleReadNotification(w http.ResponseWriter, r *http.Request) {
	withID(func(r *http.Request, id int64) (service.NotificationDTO, error) {
		return s.appointments.MarkNotificationRead(r.Context(), currentUser(r).UserID, id)
	})(w, r)
}

func (s *Server) handleReadAllNotifications(w http.ResponseWriter, r *http.Request) {
	n, err := s.appointments.MarkAllNotificationsRead(r.Context(), currentUser(r).UserID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]int64{"updated": n})
}

// ---- Doktor ----

func (s *Server) handleDoctorAppointments(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	list, err := s.appointments.DoctorAppointments(r.Context(), currentUser(r).UserID, q.Get("status"), q.Get("date"))
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}

func (s *Server) handleDoctorApprove(w http.ResponseWriter, r *http.Request) {
	withID(func(r *http.Request, id int64) (service.AppointmentDTO, error) {
		return s.appointments.DoctorApprove(r.Context(), currentUser(r).UserID, id)
	})(w, r)
}

func (s *Server) handleDoctorReject(w http.ResponseWriter, r *http.Request) {
	withID(func(r *http.Request, id int64) (service.AppointmentDTO, error) {
		return s.appointments.DoctorReject(r.Context(), currentUser(r).UserID, id)
	})(w, r)
}

func (s *Server) handleDoctorCancel(w http.ResponseWriter, r *http.Request) {
	withID(func(r *http.Request, id int64) (service.AppointmentDTO, error) {
		return s.appointments.DoctorCancel(r.Context(), currentUser(r).UserID, id)
	})(w, r)
}

// ---- Kurum yöneticisi ----

func (s *Server) handleManageAppointments(w http.ResponseWriter, r *http.Request) {
	doctorID, err := queryID(r, "doctor_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	q := r.URL.Query()
	list, err := s.appointments.InstitutionAppointments(r.Context(), currentUser(r).InstitutionID, service.ManageAppointmentsQuery{
		Date: q.Get("date"), DoctorID: doctorID, Status: q.Get("status"),
	})
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}

func (s *Server) handleAdminCancel(w http.ResponseWriter, r *http.Request) {
	withID(func(r *http.Request, id int64) (service.AppointmentDTO, error) {
		return s.appointments.AdminCancel(r.Context(), currentUser(r).InstitutionID, id)
	})(w, r)
}
