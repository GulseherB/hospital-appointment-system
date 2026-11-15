// Package clock, sistemin tek saat dilimini (Türkiye) tanımlar.
// Tüm tarih-saat hesapları bu paketteki konum üzerinden yapılır.
package clock

import (
	"time"
	_ "time/tzdata" // Windows'ta saat dilimi veritabanı olmayabilir; Go içine gömülür.
)

// Location, sistemin kullandığı saat dilimidir.
var Location = mustLoadLocation("Europe/Istanbul")

func mustLoadLocation(name string) *time.Location {
	loc, err := time.LoadLocation(name)
	if err != nil {
		panic("saat dilimi yüklenemedi: " + err.Error())
	}
	return loc
}

// Now, şu anı Türkiye saatiyle ve saniye hassasiyetinde döndürür
// (DATETIME sütunları saniye hassasiyetindedir).
func Now() time.Time {
	return time.Now().In(Location).Truncate(time.Second)
}
