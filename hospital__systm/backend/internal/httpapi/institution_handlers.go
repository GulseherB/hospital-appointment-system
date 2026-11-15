package httpapi

import (
	"net/http"
	"strconv"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/service"
)

// queryID, isteğe bağlı sorgu parametresini okur: boşsa 0, geçersizse INVALID_REQUEST.
func queryID(r *http.Request, name string) (int64, error) {
	raw := r.URL.Query().Get(name)
	if raw == "" {
		return 0, nil
	}
	id, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || id <= 0 {
		return 0, apperr.InvalidRequest("Geçersiz " + name + " değeri.")
	}
	return id, nil
}

// ---- Kurum başvurusu (herkes) ----

func (s *Server) handleCreateApplication(w http.ResponseWriter, r *http.Request) {
	var in service.ApplicationInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	app, err := s.institutions.Apply(r.Context(), in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, app)
}

// ---- Süper admin ----

func (s *Server) handleListApplications(w http.ResponseWriter, r *http.Request) {
	list, err := s.institutions.ListApplications(r.Context(), r.URL.Query().Get("status"))
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}

func (s *Server) handleApproveApplication(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	app, err := s.institutions.Approve(r.Context(), id)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, app)
}

func (s *Server) handleRejectApplication(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	app, err := s.institutions.Reject(r.Context(), id)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, app)
}

func (s *Server) handleAdminListInstitutions(w http.ResponseWriter, r *http.Request) {
	list, err := s.institutions.ListInstitutions(r.Context(), false)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}
