// Package repository, db erişimini iş mantığından ayırır (Repository kalıbı).
// Fonksiyonlar hem *sql.DB hem *sql.Tx ile çalışır (DBTX arayüzü).
package repository

import (
	"context"
	"database/sql"
	"errors"
	"strings"

	"github.com/go-sql-driver/mysql"
)

// DBTX, *sql.DB ve *sql.Tx'in ortak arayüzüdür.
type DBTX interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

// ErrNotFound, kayıt bulunamadığında döner.
var ErrNotFound = errors.New("kayıt bulunamadı")

// DuplicateKey, err bir benzersizlik ihlaliyse ihlal edilen anahtarın adını döndürür
// (ör. "users.uq_users_email").
func DuplicateKey(err error) (string, bool) {
	var me *mysql.MySQLError
	if errors.As(err, &me) && me.Number == 1062 {
		msg := me.Message
		if i := strings.LastIndex(msg, "for key '"); i >= 0 {
			return strings.TrimSuffix(msg[i+len("for key '"):], "'"), true
		}
		return "", true
	}
	return "", false
}

// InTx, fn'i bir işlem içinde çalıştırır; hata olursa geri alır.
func InTx(ctx context.Context, db *sql.DB, fn func(tx *sql.Tx) error) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback()
		return err
	}
	return tx.Commit()
}

func nullString(s string) any {
	if s == "" {
		return nil
	}
	return s
}
