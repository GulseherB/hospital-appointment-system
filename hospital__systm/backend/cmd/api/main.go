// api komutu, REST sunucusunu başlatır: go run ./cmd/api
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"hospital/backend/internal/auth"
	"hospital/backend/internal/clock"
	"hospital/backend/internal/config"
	"hospital/backend/internal/db"
	"hospital/backend/internal/httpapi"
	"hospital/backend/internal/service"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	if err := cfg.ValidateDB(); err != nil {
		log.Fatal(err)
	}

	conn, err := db.Open(cfg, false)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	tokens, err := auth.NewTokens(cfg.JWTSecret, time.Now)
	if err != nil {
		log.Fatal(err)
	}
	authService, err := service.NewAuthService(conn, tokens, clock.Now)
	if err != nil {
		log.Fatal(err)
	}

	appointments := service.NewAppointmentService(conn, clock.Now)

	server := &http.Server{
		Addr: cfg.HTTPAddr,
		Handler: httpapi.NewServer(tokens, httpapi.Services{
			Auth:         authService,
			Institutions: service.NewInstitutionService(conn, clock.Now),
			Manage:       service.NewManageService(conn, clock.Now),
			Appointments: appointments,
		}).Handler(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go runScheduler(ctx, appointments)

	go func() {
		log.Printf("API dinleniyor: %s (/api/v1)", cfg.HTTPAddr)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	}()

	<-ctx.Done()
	log.Println("sunucu kapatılıyor...")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("kapatma hatası: %v", err)
	}
}

// runScheduler, zamanlanmış işi açılışta bir kez, sonra her dakika çalıştırır:
// 12 saatten az kalan bekleyen randevuları otomatik iptal eder, bitişi geçen onaylıları tamamlar.
func runScheduler(ctx context.Context, appointments *service.AppointmentService) {
	run := func() {
		res, err := appointments.RunMaintenance(ctx)
		if err != nil {
			if ctx.Err() == nil {
				log.Printf("zamanlanmış iş hatası: %v", err)
			}
			return
		}
		if res.AutoCancelled > 0 || res.Completed > 0 {
			log.Printf("zamanlanmış iş: %d otomatik iptal, %d tamamlandı", res.AutoCancelled, res.Completed)
		}
	}
	run()
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			run()
		}
	}
}
