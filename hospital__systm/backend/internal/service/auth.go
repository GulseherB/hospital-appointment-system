// Package service, iş kurallarını uygular. HTTP'den ve SQL ayrıntılarından bağımsızdır.
package service

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/auth"
	"hospital/backend/internal/domain"
	"hospital/backend/internal/repository"
	"hospital/backend/internal/security"
	"hospital/backend/internal/validate"
)

// AuthService, kayıt, giriş ve şifre işlemlerini yürütür.
type AuthService struct {
	db     *sql.DB
	tokens *auth.Tokens
	now    func() time.Time
	// dummyHash, olmayan kullanıcıda da bcrypt karşılaştırması yapıp yanıt süresini eşitlemek içindir.
	dummyHash string
}

// NewAuthService, servisi oluşturur.
func NewAuthService(db *sql.DB, tokens *auth.Tokens, now func() time.Time) (*AuthService, error) {
	hash, err := security.HashPassword("dummy-password-for-timing")
	if err != nil {
		return nil, err
	}
	return &AuthService{db: db, tokens: tokens, now: now, dummyHash: hash}, nil
}

// SessionUser, giriş yanıtındaki kullanıcı bilgisidir.
type SessionUser struct {
	ID            int64       `json:"id"`
	Role          domain.Role `json:"role"`
	FirstName     string      `json:"first_name"`
	LastName      string      `json:"last_name"`
	Email         string      `json:"email"`
	InstitutionID int64       `json:"institution_id,omitempty"`
}

// Session, giriş, kayıt ve şifre değiştirme yanıtıdır.
type Session struct {
	Token              string      `json:"token"`
	MustChangePassword bool        `json:"must_change_password"`
	User               SessionUser `json:"user"`
}

func (s *AuthService) session(u repository.User) (Session, error) {
	token, err := s.tokens.Issue(auth.Identity{UserID: u.ID, Role: u.Role, InstitutionID: u.InstitutionID})
	if err != nil {
		return Session{}, err
	}
	return Session{
		Token:              token,
		MustChangePassword: u.MustChangePassword,
		User: SessionUser{
			ID: u.ID, Role: u.Role, FirstName: u.FirstName, LastName: u.LastName,
			Email: u.Email, InstitutionID: u.InstitutionID,
		},
	}, nil
}

// RegisterInput, hasta kaydı isteğidir.
type RegisterInput struct {
	FirstName  string `json:"first_name"`
	LastName   string `json:"last_name"`
	NationalID string `json:"national_id"`
	Email      string `json:"email"`
	Phone      string `json:"phone"`
	Password   string `json:"password"`
}

// RegisterPatient, yeni hasta hesabı açar ve oturum döndürür.
func (s *AuthService) RegisterPatient(ctx context.Context, in RegisterInput) (Session, error) {
	var v validate.Errors
	firstName := v.Text(in.FirstName, "Ad", 100)
	lastName := v.Text(in.LastName, "Soyad", 100)
	nationalID := v.NationalID(in.NationalID)
	email := v.Email(in.Email, "E-posta")
	phone := v.Phone(in.Phone, "Telefon")
	password := v.Password(in.Password, "Şifre")
	if err := v.Err(); err != nil {
		return Session{}, err
	}

	hash, err := security.HashPassword(password)
	if err != nil {
		return Session{}, err
	}

	var user repository.User
	err = repository.InTx(ctx, s.db, func(tx *sql.Tx) error {
		if used, err := repository.EmailInUse(ctx, tx, email); err != nil {
			return err
		} else if used {
			return apperr.EmailExists()
		}
		if used, err := repository.NationalIDInUse(ctx, tx, nationalID); err != nil {
			return err
		} else if used {
			return apperr.NationalIDExists()
		}
		id, err := repository.InsertUser(ctx, tx, repository.NewUser{
			Role: domain.RolePatient, FirstName: firstName, LastName: lastName,
			Email: email, Phone: phone, PasswordHash: hash,
		}, s.now())
		if err != nil {
			return mapDuplicate(err)
		}
		if err := repository.InsertPatient(ctx, tx, id, nationalID); err != nil {
			return mapDuplicate(err)
		}
		user = repository.User{ID: id, Role: domain.RolePatient, FirstName: firstName, LastName: lastName, Email: email}
		return nil
	})
	if err != nil {
		return Session{}, err
	}
	return s.session(user)
}

// mapDuplicate, eşzamanlı kayıtta oluşan benzersizlik ihlalini sözleşme hatasına çevirir.
func mapDuplicate(err error) error {
	key, ok := repository.DuplicateKey(err)
	if !ok {
		return err
	}
	switch {
	case strings.Contains(key, "email"):
		return apperr.EmailExists()
	case strings.Contains(key, "national_id"):
		return apperr.NationalIDExists()
	}
	return err
}

// LoginInput, giriş isteğidir.
type LoginInput struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

var errBadCredentials = apperr.Unauthorized("E-posta veya şifre hatalı.")

// Login, e-posta ve şifreyi doğrular. Kullanıcı yoksa kurum başvurusu durumuna bakılır.
func (s *AuthService) Login(ctx context.Context, in LoginInput) (Session, error) {
	email := strings.ToLower(strings.TrimSpace(in.Email))
	if email == "" || in.Password == "" {
		return Session{}, apperr.InvalidRequest("E-posta ve şifre zorunludur.")
	}

	user, err := repository.UserByEmail(ctx, s.db, email)
	if err == nil {
		if !security.CheckPassword(user.PasswordHash, in.Password) {
			return Session{}, errBadCredentials
		}
		return s.session(user)
	}
	if !errors.Is(err, repository.ErrNotFound) {
		return Session{}, err
	}

	// Kullanıcı yok: onaylanmamış kurum başvurusu olabilir. Şifre doğruysa durumu bildir.
	status, hash, err := repository.LatestApplicationByAdminEmail(ctx, s.db, email)
	if errors.Is(err, repository.ErrNotFound) {
		security.CheckPassword(s.dummyHash, in.Password)
		return Session{}, errBadCredentials
	}
	if err != nil {
		return Session{}, err
	}
	if !security.CheckPassword(hash, in.Password) {
		return Session{}, errBadCredentials
	}
	switch status {
	case domain.ApplicationPending:
		return Session{}, apperr.ApplicationPending()
	case domain.ApplicationRejected:
		return Session{}, apperr.ApplicationRejected()
	}
	return Session{}, errBadCredentials
}

// ChangePasswordInput, şifre değiştirme isteğidir.
type ChangePasswordInput struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

// ChangePassword, mevcut şifreyi doğrular, yenisini kaydeder ve geçici şifre işaretini kaldırır.
func (s *AuthService) ChangePassword(ctx context.Context, userID int64, in ChangePasswordInput) (Session, error) {
	var v validate.Errors
	v.Check(in.CurrentPassword != "", "Mevcut şifre zorunludur.")
	newPassword := v.Password(in.NewPassword, "Yeni şifre")
	v.Check(in.NewPassword == "" || in.NewPassword != in.CurrentPassword, "Yeni şifre mevcut şifreyle aynı olamaz.")
	if err := v.Err(); err != nil {
		return Session{}, err
	}

	user, err := repository.UserByID(ctx, s.db, userID)
	if errors.Is(err, repository.ErrNotFound) {
		return Session{}, apperr.Unauthorized("Oturum geçersiz.")
	}
	if err != nil {
		return Session{}, err
	}
	if !security.CheckPassword(user.PasswordHash, in.CurrentPassword) {
		return Session{}, apperr.InvalidRequest("Mevcut şifre hatalı.")
	}

	hash, err := security.HashPassword(newPassword)
	if err != nil {
		return Session{}, err
	}
	if err := repository.SetPassword(ctx, s.db, userID, hash, false); err != nil {
		return Session{}, err
	}
	user.MustChangePassword = false
	return s.session(user)
}

// MeResponse, /auth/me yanıtıdır (token içermez).
type MeResponse struct {
	MustChangePassword bool        `json:"must_change_password"`
	User               SessionUser `json:"user"`
}

// Me, oturumdaki kullanıcının güncel bilgisini döndürür.
func (s *AuthService) Me(ctx context.Context, userID int64) (MeResponse, error) {
	u, err := repository.UserByID(ctx, s.db, userID)
	if errors.Is(err, repository.ErrNotFound) {
		return MeResponse{}, apperr.Unauthorized("Oturum geçersiz.")
	}
	if err != nil {
		return MeResponse{}, err
	}
	return MeResponse{
		MustChangePassword: u.MustChangePassword,
		User: SessionUser{
			ID: u.ID, Role: u.Role, FirstName: u.FirstName, LastName: u.LastName,
			Email: u.Email, InstitutionID: u.InstitutionID,
		},
	}, nil
}

// AuthState, her istekte db'den okunan güncel kullanıcı durumudur.
type AuthState struct {
	UserID             int64
	Role               domain.Role
	InstitutionID      int64
	MustChangePassword bool
}

// CurrentState, token sahibinin güncel rolünü ve şifre durumunu getirir.
// Rol ve kurum bilgisi tokenden değil db'den alınır; böylece sıfırlanan şifre anında etkili olur.
func (s *AuthService) CurrentState(ctx context.Context, userID int64) (AuthState, error) {
	u, err := repository.UserByID(ctx, s.db, userID)
	if errors.Is(err, repository.ErrNotFound) {
		return AuthState{}, apperr.Unauthorized("Oturum geçersiz.")
	}
	if err != nil {
		return AuthState{}, err
	}
	return AuthState{UserID: u.ID, Role: u.Role, InstitutionID: u.InstitutionID, MustChangePassword: u.MustChangePassword}, nil
}
