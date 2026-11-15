// Package db, MySQL bağlantısını açar.
package db

import (
	"context"
	"database/sql"
	"fmt"
	"net"
	"time"

	"github.com/go-sql-driver/mysql"

	"hospital/backend/internal/clock"
	"hospital/backend/internal/config"
)

// DSN, bağlantı dizesini üretir. Tarihler Türkiye saatiyle okunur ve yazılır.
// multiStatements yalnızca migration için açılır.
func DSN(c config.Config, multiStatements bool) string {
	m := mysql.NewConfig()
	m.User = c.DBUser
	m.Passwd = c.DBPassword
	m.Net = "tcp"
	m.Addr = net.JoinHostPort(c.DBHost, c.DBPort)
	m.DBName = c.DBName
	m.ParseTime = true
	m.Loc = clock.Location
	m.MultiStatements = multiStatements
	m.Params = map[string]string{"charset": "utf8mb4"}
	return m.FormatDSN()
}

// Open, bağlantı havuzunu açar ve erişilebilirliği denetler.
func Open(c config.Config, multiStatements bool) (*sql.DB, error) {
	conn, err := sql.Open("mysql", DSN(c, multiStatements))
	if err != nil {
		return nil, err
	}
	conn.SetMaxOpenConns(20)
	conn.SetMaxIdleConns(10)
	conn.SetConnMaxLifetime(30 * time.Minute)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := conn.PingContext(ctx); err != nil {
		conn.Close()
		return nil, fmt.Errorf("db bağlantısı kurulamadı (%s:%s/%s): %w", c.DBHost, c.DBPort, c.DBName, err)
	}
	return conn, nil
}
