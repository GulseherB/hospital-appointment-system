package security

import (
	"strings"
	"testing"
)

func TestHashAndCheckPassword(t *testing.T) {
	hash, err := HashPassword("Secret_Pass_1")
	if err != nil {
		t.Fatal(err)
	}
	if hash == "Secret_Pass_1" || !strings.HasPrefix(hash, "$2") {
		t.Fatalf("özet bcrypt biçiminde değil: %q", hash)
	}
	if !CheckPassword(hash, "Secret_Pass_1") {
		t.Fatal("doğru şifre reddedildi")
	}
	if CheckPassword(hash, "wrong_password") {
		t.Fatal("yanlış şifre kabul edildi")
	}
}

func TestValidatePassword(t *testing.T) {
	if err := ValidatePassword("short"); err != ErrPasswordTooShort {
		t.Fatalf("kısa şifre için ErrPasswordTooShort beklendi, gelen: %v", err)
	}
	if err := ValidatePassword(strings.Repeat("a", 73)); err != ErrPasswordTooLong {
		t.Fatalf("uzun şifre için ErrPasswordTooLong beklendi, gelen: %v", err)
	}
	if err := ValidatePassword("şğüöçıİa"); err != nil { // 8 karakter, Türkçe harfler
		t.Fatalf("8 karakterlik şifre kabul edilmeli: %v", err)
	}
}

func TestGenerateTempPasswordIsUniqueAndValid(t *testing.T) {
	seen := map[string]bool{}
	for i := 0; i < 100; i++ {
		p, err := GenerateTempPassword()
		if err != nil {
			t.Fatal(err)
		}
		if len(p) != TempPasswordLength {
			t.Fatalf("uzunluk %d, beklenen %d", len(p), TempPasswordLength)
		}
		if err := ValidatePassword(p); err != nil {
			t.Fatalf("geçici şifre kurala uymuyor: %v", err)
		}
		if seen[p] {
			t.Fatalf("aynı geçici şifre iki kez üretildi: %s", p)
		}
		seen[p] = true
	}
}
