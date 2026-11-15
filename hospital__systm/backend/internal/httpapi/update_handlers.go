package httpapi

import (
	"net/http"

	"hospital/backend/internal/service"
)

// Güncelleme, pasifleştirme ve şifre sıfırlama uç noktaları (B5).

// withIDBody, yoldaki {id} ve JSON gövdeyi okuyup işleyiciye verir; sonucu 200 ile yazar.
func withIDBody[In any, Out any](fn func(r *http.Request, id int64, in In) (Out, error)) http.HandlerFunc {
	return withID(func(r *http.Request, id int64) (Out, error) {
		var in In
		if err := decodeJSON(r, &in); err != nil {
			var zero Out
			return zero, err
		}
		return fn(r, id, in)
	})
}

func (s *Server) handleUpdateBranch(w http.ResponseWriter, r *http.Request) {
	withIDBody(func(r *http.Request, id int64, in service.BranchUpdateInput) (service.BranchDTO, error) {
		return s.manage.UpdateBranch(r.Context(), currentUser(r).InstitutionID, id, in)
	})(w, r)
}

func (s *Server) handleUpdateDepartment(w http.ResponseWriter, r *http.Request) {
	withIDBody(func(r *http.Request, id int64, in service.DepartmentUpdateInput) (service.DepartmentDTO, error) {
		return s.manage.UpdateDepartment(r.Context(), currentUser(r).InstitutionID, id, in)
	})(w, r)
}

func (s *Server) handleUpdateService(w http.ResponseWriter, r *http.Request) {
	withIDBody(func(r *http.Request, id int64, in service.ServiceUpdateInput) (service.ServiceDTO, error) {
		return s.manage.UpdateService(r.Context(), currentUser(r).InstitutionID, id, in)
	})(w, r)
}

func (s *Server) handleUpdateDoctor(w http.ResponseWriter, r *http.Request) {
	withIDBody(func(r *http.Request, id int64, in service.DoctorUpdateInput) (service.DoctorUpdateDTO, error) {
		return s.manage.UpdateDoctor(r.Context(), currentUser(r).InstitutionID, id, in)
	})(w, r)
}

func (s *Server) handleResetDoctorPassword(w http.ResponseWriter, r *http.Request) {
	withID(func(r *http.Request, id int64) (service.CreatedDoctorDTO, error) {
		return s.manage.ResetDoctorPassword(r.Context(), currentUser(r).InstitutionID, id)
	})(w, r)
}

func (s *Server) handleSetInstitutionActive(w http.ResponseWriter, r *http.Request) {
	withIDBody(func(r *http.Request, id int64, in service.InstitutionActiveInput) (service.InstitutionDTO, error) {
		return s.institutions.SetInstitutionActive(r.Context(), id, in)
	})(w, r)
}

func (s *Server) handleResetAdminPassword(w http.ResponseWriter, r *http.Request) {
	withID(func(r *http.Request, id int64) (service.AdminPasswordResetDTO, error) {
		return s.institutions.ResetAdminPassword(r.Context(), id)
	})(w, r)
}
