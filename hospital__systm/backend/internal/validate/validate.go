// Package validate, istek alanlarının biçim kurallarını içerir.
// Hatalar alan adlarıyla birlikte toplanır ve tek bir INVALID_REQUEST hatası olarak döner.
package validate

import (
	"net/mail"
	"regexp"
	"strings"
	"unicode/utf8"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/security"
)

var (
	nationalIDPattern = regexp.MustCompile(`^[0-9]{11}$`)
	phonePattern      = regexp.MustCompile(`^[0-9+ ]{10,20}$`)
)

// Errors, alan hatalarını biriktirir.
type Errors struct {
	messages []string
}

func (v *Errors) add(msg string) { v.messages = append(v.messages, msg) }

// Err, hata varsa INVALID_REQUEST döndürür; yoksa nil.
func (v *Errors) Err() error {
	if len(v.messages) == 0 {
		return nil
	}
	return apperr.InvalidRequest(strings.Join(v.messages, " "))
}

// Text, boş olmamalı ve en fazla max karakter olmalı. Kırpılmış değeri döndürür.
func (v *Errors) Text(value, label string, max int) string {
	s := strings.TrimSpace(value)
	if s == "" {
		v.add(label + " boş bırakılamaz.")
	} else if utf8.RuneCountInString(s) > max {
		v.add(label + " çok uzun.")
	}
	return s
}

// OptionalText, boş olabilir; doluysa en fazla max karakter.
func (v *Errors) OptionalText(value, label string, max int) string {
	s := strings.TrimSpace(value)
	if utf8.RuneCountInString(s) > max {
		v.add(label + " çok uzun.")
	}
	return s
}

// Email, biçimi denetler ve küçük harfli değeri döndürür.
func (v *Errors) Email(value, label string) string {
	s := strings.ToLower(strings.TrimSpace(value))
	addr, err := mail.ParseAddress(s)
	if s == "" || err != nil || addr.Address != s || !strings.Contains(s[strings.LastIndex(s, "@")+1:], ".") || len(s) > 255 {
		v.add(label + " geçerli bir e-posta adresi olmalıdır.")
	}
	return s
}

// Phone, 10–20 karakter; rakam, boşluk ve + içerebilir.
func (v *Errors) Phone(value, label string) string {
	s := strings.TrimSpace(value)
	if !phonePattern.MatchString(s) {
		v.add(label + " geçerli bir telefon numarası olmalıdır.")
	}
	return s
}

// NationalID, 11 haneli ve yalnızca rakam.
func (v *Errors) NationalID(value string) string {
	s := strings.TrimSpace(value)
	if !nationalIDPattern.MatchString(s) {
		v.add("TC kimlik numarası 11 haneli ve yalnızca rakam olmalıdır.")
	}
	return s
}

// Password, şifre kuralını denetler (kırpılmaz).
func (v *Errors) Password(value, label string) string {
	switch security.ValidatePassword(value) {
	case security.ErrPasswordTooShort:
		v.add(label + " en az 8 karakter olmalıdır.")
	case security.ErrPasswordTooLong:
		v.add(label + " en fazla 72 bayt olabilir.")
	}
	return value
}

// OptionalPhone, boş olabilir; doluysa telefon biçiminde olmalı.
func (v *Errors) OptionalPhone(value, label string) string {
	s := strings.TrimSpace(value)
	if s != "" && !phonePattern.MatchString(s) {
		v.add(label + " geçerli bir telefon numarası olmalıdır.")
	}
	return s
}

// ID, pozitif kimlik olmalı.
func (v *Errors) ID(value int64, label string) int64 {
	if value <= 0 {
		v.add(label + " zorunludur.")
	}
	return value
}

var pricePattern = regexp.MustCompile(`^[0-9]{1,8}(\.[0-9]{1,2})?$`)

// Price, negatif olmayan, en fazla 2 ondalıklı ücret metni ("750" veya "750.50").
func (v *Errors) Price(value string) string {
	s := strings.TrimSpace(value)
	if !pricePattern.MatchString(s) {
		v.add("Ücret sayı olmalıdır (ör. 750 veya 750.50).")
	}
	return s
}

// DurationMin, hizmet süresi 1–480 dakika.
func (v *Errors) DurationMin(value int) int {
	if value < 1 || value > 480 {
		v.add("Süre 1 ile 480 dakika arasında olmalıdır.")
	}
	return value
}

// OneOf, değer izin verilenlerden biri olmalı.
func (v *Errors) OneOf(value string, allowed []string, message string) string {
	for _, a := range allowed {
		if value == a {
			return value
		}
	}
	v.add(message)
	return value
}

// Check, koşul sağlanmıyorsa mesajı ekler.
func (v *Errors) Check(ok bool, message string) {
	if !ok {
		v.add(message)
	}
}
