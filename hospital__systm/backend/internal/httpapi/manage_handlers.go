package httpapi

import (
	"net/http"

	"hospital/backend/internal/service"
)

// Kurum yöneticisi uç noktaları. Kurum kimliği her zaman oturumdan (db) alınır, istemciden alınmaz.

func (s *Server) handleListBranches(w http.ResponseWriter, r *http.Request) {
	list, err := s.manage.ListBranches(r.Context(), currentUser(r).InstitutionID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}

func (s *Server) handleCreateBranch(w http.ResponseWriter, r *http.Request) {
	var in service.BranchInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	b, err := s.manage.CreateBranch(r.Context(), currentUser(r).InstitutionID, in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, b)
}

func (s *Server) handleGetWorkingHours(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	items, err := s.manage.GetWorkingHours(r.Context(), currentUser(r).InstitutionID, id)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(items))
}

func (s *Server) handleSetWorkingHours(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	var in service.WorkingHoursInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	items, err := s.manage.SetWorkingHours(r.Context(), currentUser(r).InstitutionID, id, in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(items))
}

func (s *Server) handleListDepartments(w http.ResponseWriter, r *http.Request) {
	branchID, err := queryID(r, "branch_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	list, err := s.manage.ListDepartments(r.Context(), currentUser(r).InstitutionID, branchID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}

func (s *Server) handleCreateDepartment(w http.ResponseWriter, r *http.Request) {
	var in service.DepartmentInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	d, err := s.manage.CreateDepartment(r.Context(), currentUser(r).InstitutionID, in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, d)
}

func (s *Server) handleListServices(w http.ResponseWriter, r *http.Request) {
	departmentID, err := queryID(r, "department_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	list, err := s.manage.ListServices(r.Context(), currentUser(r).InstitutionID, departmentID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}

func (s *Server) handleCreateService(w http.ResponseWriter, r *http.Request) {
	var in service.ServiceInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	sv, err := s.manage.CreateService(r.Context(), currentUser(r).InstitutionID, in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, sv)
}

func (s *Server) handleListDoctors(w http.ResponseWriter, r *http.Request) {
	branchID, err := queryID(r, "branch_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	departmentID, err := queryID(r, "department_id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	list, err := s.manage.ListDoctors(r.Context(), currentUser(r).InstitutionID, branchID, departmentID)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(list))
}

func (s *Server) handleCreateDoctor(w http.ResponseWriter, r *http.Request) {
	var in service.DoctorInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	d, err := s.manage.CreateDoctor(r.Context(), currentUser(r).InstitutionID, in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, d)
}

func (s *Server) handleSetDoctorServices(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	var in service.DoctorServicesInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	d, err := s.manage.SetDoctorServices(r.Context(), currentUser(r).InstitutionID, id, in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, d)
}

func (s *Server) handleGetAvailability(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	items, err := s.manage.GetAvailability(r.Context(), currentUser(r).InstitutionID, id)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(items))
}

func (s *Server) handleSetAvailability(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		writeError(w, r, err)
		return
	}
	var in service.AvailabilityInput
	if err := decodeJSON(r, &in); err != nil {
		writeError(w, r, err)
		return
	}
	items, err := s.manage.SetAvailability(r.Context(), currentUser(r).InstitutionID, id, in)
	if err != nil {
		writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, listResponse(items))
}
