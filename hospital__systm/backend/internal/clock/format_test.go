package clock

import (
	"encoding/json"
	"testing"
	"time"
)

func TestDateTimeJSON(t *testing.T) {
	in := DateTime(time.Date(2026, 11, 20, 9, 30, 0, 0, Location))
	b, err := json.Marshal(in)
	if err != nil || string(b) != `"2026-11-20T09:30:00"` {
		t.Fatalf("beklenmeyen JSON: %s (%v)", b, err)
	}
	var out DateTime
	if err := json.Unmarshal(b, &out); err != nil || !out.Time().Equal(in.Time()) {
		t.Fatalf("geri okuma hatalı: %v %v", out.Time(), err)
	}
	if err := json.Unmarshal([]byte(`"2026-11-20T09:30:00Z"`), &out); err == nil {
		t.Fatal("saat dilimi ekli değer kabul edilmemeli")
	}
}

func TestParseTimeOfDay(t *testing.T) {
	cases := map[string]int{"09:00": 540, "12:30": 750, "23:59": 1439, "17:00:00": 1020}
	for s, want := range cases {
		got, err := ParseTimeOfDay(s)
		if err != nil || int(got) != want {
			t.Errorf("%s → %d, %v (beklenen %d)", s, got, err, want)
		}
	}
	for _, bad := range []string{"9:00", "24:00", "12:60", "12", "ab:cd", "10:00:30"} {
		if _, err := ParseTimeOfDay(bad); err == nil {
			t.Errorf("%q kabul edilmemeliydi", bad)
		}
	}
	if TimeOfDay(545).String() != "09:05" || TimeOfDay(545).SQL() != "09:05:00" {
		t.Error("biçimleme hatalı")
	}
}

func TestISOWeekday(t *testing.T) {
	monday := time.Date(2026, 11, 16, 10, 0, 0, 0, Location)
	sunday := time.Date(2026, 11, 22, 10, 0, 0, 0, Location)
	if ISOWeekday(monday) != 1 || ISOWeekday(sunday) != 7 {
		t.Fatal("gün numarası hatalı")
	}
}
