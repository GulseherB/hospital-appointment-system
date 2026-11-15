package httpapi

import (
	"context"
	"log"
	"net/http"
	"runtime/debug"
	"slices"
	"strings"
	"time"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/domain"
	"hospital/backend/internal/service"
)

type ctxKey int

const authStateKey ctxKey = 1

// currentUser, auth ara katmanının bağlama koyduğu kullanıcı durumunu döndürür.
func currentUser(r *http.Request) service.AuthState {
	s, _ := r.Context().Value(authStateKey).(service.AuthState)
	return s
}

// cors, Flutter web istemcisinin farklı porttan erişmesine izin verir.
// Kimlik doğrulama çerez değil Authorization başlığıyla yapıldığı için "*" güvenlidir.
func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("Access-Control-Allow-Origin", "*")
		h.Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		h.Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, OPTIONS")
		h.Set("Access-Control-Max-Age", "600")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

// logRequests, her isteği yöntem, yol, durum ve süreyle loglar (gövde ve başlıklar loglanmaz).
func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		log.Printf("%s %s %d %s", r.Method, r.URL.Path, rec.status, time.Since(start).Round(time.Millisecond))
	})
}

// recoverPanics, beklenmeyen hatada sunucunun çökmesini önler.
func recoverPanics(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				log.Printf("PANIC %s %s: %v\n%s", r.Method, r.URL.Path, rec, debug.Stack())
				writeError(w, r, apperr.Internal())
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// authOptions, korumalı uç noktanın kurallarıdır.
type authOptions struct {
	roles []domain.Role // boşsa her rol
	// allowTempPassword, geçici şifreyle de erişilebilir mi (yalnızca şifre değiştirme).
	allowTempPassword bool
}

// requireAuth, tokeni doğrular, güncel kullanıcı durumunu db'den okur ve kuralları uygular.
// Sıra: 401 (token) → 403 PASSWORD_CHANGE_REQUIRED → 403 FORBIDDEN (rol).
func (s *Server) requireAuth(opts authOptions, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		raw, ok := strings.CutPrefix(header, "Bearer ")
		if !ok || strings.TrimSpace(raw) == "" {
			writeError(w, r, apperr.Unauthorized("Oturum açmanız gerekiyor."))
			return
		}
		identity, err := s.tokens.Parse(strings.TrimSpace(raw))
		if err != nil {
			writeError(w, r, apperr.Unauthorized("Oturumunuz geçersiz veya süresi dolmuş. Lütfen tekrar giriş yapın."))
			return
		}
		state, err := s.auth.CurrentState(r.Context(), identity.UserID)
		if err != nil {
			writeError(w, r, err)
			return
		}
		if state.MustChangePassword && !opts.allowTempPassword {
			writeError(w, r, apperr.PasswordChangeRequired())
			return
		}
		if len(opts.roles) > 0 && !slices.Contains(opts.roles, state.Role) {
			writeError(w, r, apperr.Forbidden())
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), authStateKey, state)))
	}
}
