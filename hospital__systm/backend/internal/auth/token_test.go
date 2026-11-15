package auth

import (
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"hospital/backend/internal/domain"
)

const testSecret = "test-secret-test-secret-test-secret-123"

func TestIssueAndParse(t *testing.T) {
	now := time.Date(2026, 11, 13, 10, 0, 0, 0, time.UTC)
	tokens, err := NewTokens(testSecret, func() time.Time { return now })
	if err != nil {
		t.Fatal(err)
	}
	raw, err := tokens.Issue(Identity{UserID: 42, Role: domain.RoleInstitutionAdmin, InstitutionID: 7})
	if err != nil {
		t.Fatal(err)
	}
	id, err := tokens.Parse(raw)
	if err != nil {
		t.Fatal(err)
	}
	if id.UserID != 42 || id.Role != domain.RoleInstitutionAdmin || id.InstitutionID != 7 {
		t.Fatalf("beklenmeyen kimlik: %+v", id)
	}
}

func TestExpiredTokenRejected(t *testing.T) {
	now := time.Date(2026, 11, 13, 10, 0, 0, 0, time.UTC)
	issuer, _ := NewTokens(testSecret, func() time.Time { return now })
	raw, _ := issuer.Issue(Identity{UserID: 1, Role: domain.RolePatient})

	later, _ := NewTokens(testSecret, func() time.Time { return now.Add(TokenTTL + time.Minute) })
	if _, err := later.Parse(raw); err == nil {
		t.Fatal("süresi dolmuş token kabul edildi")
	}
}

func TestWrongSecretAndAlgorithmRejected(t *testing.T) {
	now := func() time.Time { return time.Now() }
	a, _ := NewTokens(testSecret, now)
	b, _ := NewTokens(strings.Repeat("x", 40), now)
	raw, _ := a.Issue(Identity{UserID: 1, Role: domain.RolePatient})
	if _, err := b.Parse(raw); err == nil {
		t.Fatal("farklı anahtarla imzalı token kabul edildi")
	}

	// "none" algoritmasıyla üretilmiş token reddedilmeli.
	unsigned := jwt.NewWithClaims(jwt.SigningMethodNone, Claims{
		Role:             domain.RoleSuperAdmin,
		RegisteredClaims: jwt.RegisteredClaims{Subject: "1", ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour))},
	})
	rawNone, _ := unsigned.SignedString(jwt.UnsafeAllowNoneSignatureType)
	if _, err := a.Parse(rawNone); err == nil {
		t.Fatal("imzasız token kabul edildi")
	}
}

func TestShortSecretRejected(t *testing.T) {
	if _, err := NewTokens("kisa", time.Now); err == nil {
		t.Fatal("kısa anahtar kabul edildi")
	}
}
