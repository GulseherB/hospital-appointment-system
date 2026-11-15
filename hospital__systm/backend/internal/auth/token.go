// Package auth, JWT üretimi ve doğrulamasını içerir.
package auth

import (
	"errors"
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"hospital/backend/internal/domain"
)

// TokenTTL, token geçerlilik süresidir (API sözleşmesi: 24 saat).
const TokenTTL = 24 * time.Hour

// MinSecretLength, JWT anahtarı için alt sınırdır.
const MinSecretLength = 32

// Claims, token içeriğidir. Kullanıcı kimliği "sub" alanındadır.
type Claims struct {
	Role          domain.Role `json:"role"`
	InstitutionID int64       `json:"institution_id,omitempty"`
	jwt.RegisteredClaims
}

// Identity, doğrulanmış tokenden çıkan bilgidir.
type Identity struct {
	UserID        int64
	Role          domain.Role
	InstitutionID int64
}

// Tokens, token üretir ve doğrular.
type Tokens struct {
	secret []byte
	now    func() time.Time
}

// NewTokens, gizli anahtarla bir Tokens oluşturur.
func NewTokens(secret string, now func() time.Time) (*Tokens, error) {
	if len(secret) < MinSecretLength {
		return nil, errors.New("JWT_SECRET en az 32 karakter olmalıdır")
	}
	return &Tokens{secret: []byte(secret), now: now}, nil
}

// Issue, kullanıcı için imzalı token üretir.
func (t *Tokens) Issue(id Identity) (string, error) {
	now := t.now()
	claims := Claims{
		Role:          id.Role,
		InstitutionID: id.InstitutionID,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   strconv.FormatInt(id.UserID, 10),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(TokenTTL)),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(t.secret)
}

// ErrInvalidToken, token geçersiz veya süresi dolmuş olduğunda döner.
var ErrInvalidToken = errors.New("geçersiz token")

// Parse, tokeni doğrular ve kimliği döndürür. Yalnızca HS256 kabul edilir.
func (t *Tokens) Parse(raw string) (Identity, error) {
	claims := &Claims{}
	_, err := jwt.ParseWithClaims(raw, claims, func(*jwt.Token) (any, error) { return t.secret, nil },
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
		jwt.WithExpirationRequired(),
		jwt.WithTimeFunc(t.now),
	)
	if err != nil {
		return Identity{}, ErrInvalidToken
	}
	userID, err := strconv.ParseInt(claims.Subject, 10, 64)
	if err != nil || userID <= 0 {
		return Identity{}, ErrInvalidToken
	}
	return Identity{UserID: userID, Role: claims.Role, InstitutionID: claims.InstitutionID}, nil
}
