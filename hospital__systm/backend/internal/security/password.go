// Package security, şifre özeti ve geçici şifre üretimini içerir.
// Şifreler hiçbir zaman düz metin saklanmaz veya loglanmaz.
package security

import (
	"crypto/rand"
	"errors"
	"math/big"
	"unicode/utf8"

	"golang.org/x/crypto/bcrypt"
)

// MinPasswordLength, kullanıcı şifreleri için alt sınırdır.
const MinPasswordLength = 8

// bcrypt 72 bayttan uzun girdiyi kabul etmez.
const maxPasswordBytes = 72

// Şifre kuralı ihlalleri (mesajlar kullanıcıya gösterilebilir).
var (
	ErrPasswordTooShort = errors.New("şifre en az 8 karakter olmalıdır")
	ErrPasswordTooLong  = errors.New("şifre en fazla 72 bayt olabilir")
)

// ValidatePassword, şifrenin uzunluk kurallarına uyup uymadığını denetler.
func ValidatePassword(password string) error {
	if utf8.RuneCountInString(password) < MinPasswordLength {
		return ErrPasswordTooShort
	}
	if len(password) > maxPasswordBytes {
		return ErrPasswordTooLong
	}
	return nil
}

// HashPassword, şifrenin bcrypt özetini üretir.
func HashPassword(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(hash), nil
}

// CheckPassword, düz şifrenin kayıtlı özetle eşleşip eşleşmediğini döndürür.
func CheckPassword(hash, password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}

// Karışabilecek karakterler (0/O, 1/l/I) çıkarıldı.
const tempPasswordAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789"

// TempPasswordLength, sistemin ürettiği geçici şifrenin uzunluğudur.
const TempPasswordLength = 12

// GenerateTempPassword, kriptografik olarak güvenli rastgele bir geçici şifre üretir.
func GenerateTempPassword() (string, error) {
	b := make([]byte, TempPasswordLength)
	max := big.NewInt(int64(len(tempPasswordAlphabet)))
	for i := range b {
		n, err := rand.Int(rand.Reader, max)
		if err != nil {
			return "", err
		}
		b[i] = tempPasswordAlphabet[n.Int64()]
	}
	return string(b), nil
}
