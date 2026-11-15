// migrate komutu, golang-migrate ile gömülü SQL migration'larını çalıştırır.
//
//	go run ./cmd/migrate up             tüm migration'ları uygular
//	go run ./cmd/migrate version        mevcut sürümü gösterir
//	go run ./cmd/migrate down -confirm  tüm tabloları siler (geri alınamaz)
package main

import (
	"errors"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/golang-migrate/migrate/v4"
	migratemysql "github.com/golang-migrate/migrate/v4/database/mysql"
	"github.com/golang-migrate/migrate/v4/source/iofs"

	"hospital/backend/internal/config"
	"hospital/backend/internal/db"
	"hospital/backend/migrations"
)

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	command := os.Args[1]
	fs := flag.NewFlagSet(command, flag.ExitOnError)
	confirm := fs.Bool("confirm", false, "geri alınamaz 'down' işlemini onaylar")
	_ = fs.Parse(os.Args[2:])

	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	if err := cfg.ValidateDB(); err != nil {
		log.Fatal(err)
	}

	conn, err := db.Open(cfg, true)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()

	source, err := iofs.New(migrations.FS, ".")
	if err != nil {
		log.Fatal(err)
	}
	driver, err := migratemysql.WithInstance(conn, &migratemysql.Config{})
	if err != nil {
		log.Fatal(err)
	}
	m, err := migrate.NewWithInstance("iofs", source, "mysql", driver)
	if err != nil {
		log.Fatal(err)
	}

	switch command {
	case "up":
		report(m.Up(), "migration'lar uygulandı")
	case "down":
		if !*confirm {
			log.Fatal("'down' tüm tabloları ve verileri siler. Emin iseniz -confirm ekleyin.")
		}
		report(m.Down(), "tüm migration'lar geri alındı")
	case "version":
		v, dirty, err := m.Version()
		if errors.Is(err, migrate.ErrNilVersion) {
			fmt.Println("henüz migration uygulanmadı")
			return
		}
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("sürüm: %d, yarım kalmış: %t\n", v, dirty)
	default:
		usage()
	}
}

func report(err error, success string) {
	if errors.Is(err, migrate.ErrNoChange) {
		fmt.Println("değişiklik yok; db güncel")
		return
	}
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(success)
}

func usage() {
	fmt.Fprintln(os.Stderr, "kullanım: migrate <up | down -confirm | version>")
	os.Exit(2)
}
