package httpapi

import (
	"net/http"

	"hospital/backend/internal/service"
)

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var in service.RegisterInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	session, err := s.auth.RegisterPatient(r.Context(), in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, session)
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var in service.LoginInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	session, err := s.auth.Login(r.Context(), in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, session)
}

func (s *Server) handleChangePassword(w http.ResponseWriter, r *http.Request) {
	var in service.ChangePasswordInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	session, err := s.auth.ChangePassword(r.Context(), currentUser(r).UserID, in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, session)
}

// handleMe, oturumdaki kullanıcıyı döndürür (uygulama açılışında kayıtlı tokeni doğrulamak için).
func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	u, err := s.auth.Me(r.Context(), currentUser(r).UserID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, u)
}
