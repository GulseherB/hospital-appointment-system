// Package apperr, API sözleşmesindeki hata kodlarını ve HTTP durumlarını tanımlar.
// Servis katmanı bu hataları döndürür; HTTP katmanı bunları JSON'a çevirir.
package apperr

import (
	"errors"
	"net/http"
)

// Error, kullanıcıya gösterilebilir bir API hatasıdır. Message Türkçedir.
type Error struct {
	Status  int
	Code    string
	Message string
}

func (e *Error) Error() string { return e.Code + ": " + e.Message }

// API sözleşmesi → Hata biçimi.
const (
	CodeInvalidRequest         = "INVALID_REQUEST"
	CodeUnauthorized           = "UNAUTHORIZED"
	CodeForbidden              = "FORBIDDEN"
	CodePasswordChangeRequired = "PASSWORD_CHANGE_REQUIRED"
	CodeApplicationPending     = "APPLICATION_PENDING"
	CodeApplicationRejected    = "APPLICATION_REJECTED"
	CodeNotFound               = "NOT_FOUND"
	CodeSlotTaken              = "SLOT_TAKEN"
	CodeNationalIDExists       = "NATIONAL_ID_EXISTS"
	CodeEmailExists            = "EMAIL_EXISTS"
	CodePatientConflict        = "PATIENT_CONFLICT"
	CodeHasFutureAppointments  = "HAS_FUTURE_APPOINTMENTS"
	CodeBusinessRuleViolation  = "BUSINESS_RULE_VIOLATION"
	CodeNameExists             = "NAME_EXISTS"
	CodeInternal               = "INTERNAL_ERROR"
)

func newErr(status int, code, message string) *Error {
	return &Error{Status: status, Code: code, Message: message}
}

func InvalidRequest(message string) *Error {
	return newErr(http.StatusBadRequest, CodeInvalidRequest, message)
}

func Unauthorized(message string) *Error {
	return newErr(http.StatusUnauthorized, CodeUnauthorized, message)
}

func Forbidden() *Error {
	return newErr(http.StatusForbidden, CodeForbidden, "Bu işlem için yetkiniz yok.")
}

func PasswordChangeRequired() *Error {
	return newErr(http.StatusForbidden, CodePasswordChangeRequired, "Devam etmek için geçici şifrenizi değiştirmelisiniz.")
}

func ApplicationPending() *Error {
	return newErr(http.StatusForbidden, CodeApplicationPending, "Kurum başvurunuz henüz onaylanmadı.")
}

func ApplicationRejected() *Error {
	return newErr(http.StatusForbidden, CodeApplicationRejected, "Kurum başvurunuz reddedildi.")
}

func NotFound(message string) *Error {
	return newErr(http.StatusNotFound, CodeNotFound, message)
}

func SlotTaken() *Error {
	return newErr(http.StatusConflict, CodeSlotTaken, "Seçilen saat artık müsait değil.")
}

func NationalIDExists() *Error {
	return newErr(http.StatusConflict, CodeNationalIDExists, "Bu TC kimlik numarasıyla kayıtlı bir hasta zaten var.")
}

func EmailExists() *Error {
	return newErr(http.StatusConflict, CodeEmailExists, "Bu e-posta adresi zaten kullanılıyor.")
}

func PatientConflict() *Error {
	return newErr(http.StatusConflict, CodePatientConflict, "Bu saatte başka bir aktif randevunuz var.")
}

func HasFutureAppointments(message string) *Error {
	return newErr(http.StatusConflict, CodeHasFutureAppointments, message)
}

func BusinessRule(message string) *Error {
	return newErr(http.StatusUnprocessableEntity, CodeBusinessRuleViolation, message)
}

func NameExists(message string) *Error {
	return newErr(http.StatusConflict, CodeNameExists, message)
}

func Internal() *Error {
	return newErr(http.StatusInternalServerError, CodeInternal, "Beklenmeyen bir sunucu hatası oluştu.")
}

// As, err zincirinde bir *Error varsa onu döndürür.
func As(err error) (*Error, bool) {
	var e *Error
	if errors.As(err, &e) {
		return e, true
	}
	return nil, false
}
