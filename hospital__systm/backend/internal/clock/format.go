package clock

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

// APIDateTimeLayout, API'deki tarih-saat biçimidir (saat dilimi eki yok, Türkiye saati).
const APIDateTimeLayout = "2006-01-02T15:04:05"

// APIDateLayout, API'deki tarih biçimidir.
const APIDateLayout = "2006-01-02"

// DateTime, JSON'a API biçiminde ("2026-11-20T09:30:00") yazılan zamandır.
type DateTime time.Time

// MarshalJSON, değeri Türkiye saatiyle API biçiminde yazar.
func (d DateTime) MarshalJSON() ([]byte, error) {
	return []byte(`"` + time.Time(d).In(Location).Format(APIDateTimeLayout) + `"`), nil
}

// UnmarshalJSON, API biçimindeki değeri Türkiye saati olarak okur.
func (d *DateTime) UnmarshalJSON(b []byte) error {
	s := strings.Trim(string(b), `"`)
	t, err := time.ParseInLocation(APIDateTimeLayout, s, Location)
	if err != nil {
		return fmt.Errorf("tarih-saat %s biçiminde olmalıdır", "YYYY-MM-DDTHH:MM:SS")
	}
	*d = DateTime(t)
	return nil
}

// Time, time.Time değerini döndürür.
func (d DateTime) Time() time.Time { return time.Time(d) }

// NullableDateTime, nil olabilen zamanı JSON'a çevirir.
func NullableDateTime(t *time.Time) *DateTime {
	if t == nil {
		return nil
	}
	d := DateTime(*t)
	return &d
}

// ParseDate, "YYYY-MM-DD" biçimindeki tarihi Türkiye saatinde gece yarısı olarak çözer.
func ParseDate(s string) (time.Time, error) {
	return time.ParseInLocation(APIDateLayout, s, Location)
}

// TimeOfDay, gün içindeki dakikadır (0–1439). API biçimi "HH:MM".
type TimeOfDay int

// ParseTimeOfDay, "HH:MM" biçimini çözer. Saniyeli db biçimi ("HH:MM:SS") de kabul edilir.
func ParseTimeOfDay(s string) (TimeOfDay, error) {
	parts := strings.Split(s, ":")
	if len(parts) != 2 && len(parts) != 3 {
		return 0, fmt.Errorf("saat HH:MM biçiminde olmalıdır: %q", s)
	}
	if len(parts[0]) != 2 || len(parts[1]) != 2 {
		return 0, fmt.Errorf("saat HH:MM biçiminde olmalıdır: %q", s)
	}
	h, err1 := strconv.Atoi(parts[0])
	m, err2 := strconv.Atoi(parts[1])
	if err1 != nil || err2 != nil || h < 0 || h > 23 || m < 0 || m > 59 {
		return 0, fmt.Errorf("geçersiz saat: %q", s)
	}
	if len(parts) == 3 && parts[2] != "00" {
		return 0, fmt.Errorf("saniye desteklenmez: %q", s)
	}
	return TimeOfDay(h*60 + m), nil
}

// String, "HH:MM" biçimi.
func (t TimeOfDay) String() string { return fmt.Sprintf("%02d:%02d", int(t)/60, int(t)%60) }

// SQL, db TIME sütunu için "HH:MM:00" biçimi.
func (t TimeOfDay) SQL() string { return t.String() + ":00" }

// On, verilen günün bu saatini döndürür.
func (t TimeOfDay) On(day time.Time) time.Time {
	y, mo, d := day.In(Location).Date()
	return time.Date(y, mo, d, int(t)/60, int(t)%60, 0, 0, Location)
}

// ISOWeekday, 1 = Pazartesi ... 7 = Pazar.
func ISOWeekday(t time.Time) int {
	wd := int(t.In(Location).Weekday())
	if wd == 0 {
		return 7
	}
	return wd
}
