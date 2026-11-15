package service

import (
	"testing"
	"time"

	"hospital/backend/internal/clock"
	"hospital/backend/internal/domain"
	"hospital/backend/internal/repository"
)

func at(day string, hm string) time.Time {
	t, err := time.ParseInLocation("2006-01-02 15:04", day+" "+hm, clock.Location)
	if err != nil {
		panic(err)
	}
	return t
}

func weekdays(start, end clock.TimeOfDay) []repository.WeeklyRange {
	var out []repository.WeeklyRange
	for d := 1; d <= 5; d++ {
		out = append(out, repository.WeeklyRange{Weekday: d, Start: start, End: end})
	}
	return out
}

// 2026-11-16 Pazartesi. "Şimdi" Pazar 2026-11-15 08:00 → ilk geçerli an Pazartesi 08:00.
var (
	testNow    = at("2026-11-15", "08:00")
	nineToFive = weekdays(9*60, 17*60)
)

func startsOn(slots []Slot, day string) []string {
	var out []string
	for _, s := range slots {
		if s.Start.Format("2006-01-02") == day {
			out = append(out, s.Start.Format("15:04"))
		}
	}
	return out
}

func TestGenerateSlotsLunchAndGrid(t *testing.T) {
	slots := GenerateSlots(SlotRequest{
		Now: testNow, DateFrom: at("2026-11-16", "00:00"), DateTo: at("2026-11-16", "00:00"), DurationMin: 30,
		WorkingHours: nineToFive,
		Doctors:      []DoctorSchedule{{DoctorID: 1, DoctorName: "A", Availability: nineToFive}},
	})
	got := startsOn(slots, "2026-11-16")
	// 09:00–11:30 (11 slot), 13:00–16:30 (15 slot). 11:45 (12:15'e taşar) ve 12:xx listelenmez.
	if len(got) != 11+15 {
		t.Fatalf("slot sayısı = %d, beklenen 26: %v", len(got), got)
	}
	for _, s := range got {
		if s == "11:45" || s[:2] == "12" {
			t.Fatalf("öğle arasıyla kesişen slot üretildi: %s", s)
		}
	}
	if got[0] != "09:00" || got[10] != "11:30" || got[11] != "13:00" || got[len(got)-1] != "16:30" {
		t.Fatalf("beklenmeyen sınırlar: %v", got)
	}
}

func TestGenerateSlotsGridRoundingAndFit(t *testing.T) {
	avail := []repository.WeeklyRange{{Weekday: 1, Start: 9*60 + 10, End: 10 * 60}}
	slots := GenerateSlots(SlotRequest{
		Now: testNow, DateFrom: at("2026-11-16", "00:00"), DateTo: at("2026-11-16", "00:00"), DurationMin: 20,
		WorkingHours: nineToFive, Doctors: []DoctorSchedule{{DoctorID: 1, Availability: avail}},
	})
	got := startsOn(slots, "2026-11-16")
	// 09:10 → 09:15 ızgarası; 20 dk sığanlar: 09:15, 09:30 (09:45+20=10:05 sığmaz).
	if len(got) != 2 || got[0] != "09:15" || got[1] != "09:30" {
		t.Fatalf("got %v", got)
	}
}

func TestGenerateSlotsLeadTimeAndHorizon(t *testing.T) {
	now := at("2026-11-16", "10:07") // Pazartesi
	slots := GenerateSlots(SlotRequest{
		Now: now, DateFrom: at("2026-11-01", "00:00"), DateTo: at("2026-12-31", "00:00"), DurationMin: 15,
		WorkingHours: weekdays(9*60, 17*60), Doctors: []DoctorSchedule{{DoctorID: 1, Availability: nineToFive}},
	})
	if len(slots) == 0 {
		t.Fatal("slot üretilmedi")
	}
	earliest := now.Add(24 * time.Hour)
	for _, s := range slots {
		if s.Start.Before(earliest) {
			t.Fatalf("24 saatten yakın slot: %v", s.Start)
		}
	}
	if first := slots[0].Start.Format("2006-01-02 15:04"); first != "2026-11-17 10:15" {
		t.Fatalf("ilk slot = %s, beklenen 2026-11-17 10:15", first)
	}
	// Ufuk: bugün + 7 gün = 2026-11-23 (Pazartesi) dahil, sonrası yok.
	if last := slots[len(slots)-1].Start.Format("2006-01-02"); last != "2026-11-23" {
		t.Fatalf("son gün = %s, beklenen 2026-11-23", last)
	}
	if got := startsOn(slots, "2026-11-21"); len(got) != 0 {
		t.Fatalf("kapalı günde (Cumartesi) slot üretildi: %v", got)
	}
}

func TestGenerateSlotsBusyAndWorkingHoursIntersection(t *testing.T) {
	busy := []repository.Interval{{Start: at("2026-11-16", "09:30"), End: at("2026-11-16", "10:00")}}
	hours := []repository.WeeklyRange{{Weekday: 1, Start: 9 * 60, End: 10*60 + 30}}
	slots := GenerateSlots(SlotRequest{
		Now: testNow, DateFrom: at("2026-11-16", "00:00"), DateTo: at("2026-11-16", "00:00"), DurationMin: 30,
		WorkingHours: hours, Doctors: []DoctorSchedule{{DoctorID: 1, Availability: nineToFive, Busy: busy}},
	})
	got := startsOn(slots, "2026-11-16")
	// Şube 10:30'da kapanıyor; 09:15, 09:30, 09:45 dolu aralıkla kesişir.
	want := []string{"09:00", "10:00"}
	if len(got) != len(want) || got[0] != want[0] || got[1] != want[1] {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestGenerateSlotsOrderedByTimeThenDoctor(t *testing.T) {
	avail := []repository.WeeklyRange{{Weekday: 1, Start: 9 * 60, End: 9*60 + 30}}
	slots := GenerateSlots(SlotRequest{
		Now: testNow, DateFrom: at("2026-11-16", "00:00"), DateTo: at("2026-11-16", "00:00"), DurationMin: 15,
		WorkingHours: nineToFive,
		Doctors: []DoctorSchedule{
			{DoctorID: 2, DoctorName: "Zeynep", Availability: avail},
			{DoctorID: 1, DoctorName: "Ali", Availability: avail},
		},
	})
	if len(slots) != 4 || slots[0].DoctorName != "Ali" || slots[1].DoctorName != "Zeynep" || !slots[2].Start.After(slots[1].Start) {
		t.Fatalf("sıralama hatalı: %+v", slots)
	}
}

func TestCancelPolicies(t *testing.T) {
	now := at("2026-11-16", "10:00")
	appt := func(status domain.AppointmentStatus, start string) repository.Appointment {
		return repository.Appointment{Status: status, StartAt: at("2026-11-16", start)}
	}
	cases := []struct {
		name   string
		policy CancelPolicy
		a      repository.Appointment
		ok     bool
	}{
		{"hasta bekleyen, 2 saat var", PatientCancelPolicy{}, appt(domain.AppointmentPending, "12:00"), true},
		{"hasta onaylı, 2 saatten az", PatientCancelPolicy{}, appt(domain.AppointmentApproved, "11:59"), false},
		{"hasta tamamlanmış", PatientCancelPolicy{}, appt(domain.AppointmentCompleted, "15:00"), false},
		{"doktor onaylı, 2 saat var", DoctorCancelPolicy{}, appt(domain.AppointmentApproved, "13:00"), true},
		{"doktor onaylı, 2 saatten az", DoctorCancelPolicy{}, appt(domain.AppointmentApproved, "11:30"), false},
		{"doktor bekleyen iptal edemez", DoctorCancelPolicy{}, appt(domain.AppointmentPending, "15:00"), false},
		{"yönetici bekleyen", AdminCancelPolicy{}, appt(domain.AppointmentPending, "15:00"), true},
		{"yönetici onaylı, 2 saatten az", AdminCancelPolicy{}, appt(domain.AppointmentApproved, "11:00"), false},
		{"yönetici reddedilmiş", AdminCancelPolicy{}, appt(domain.AppointmentRejected, "15:00"), false},
		{"sistem bekleyen, 12 saatten az", SystemCancelPolicy{}, appt(domain.AppointmentPending, "21:59"), true},
		{"sistem bekleyen, tam 12 saat", SystemCancelPolicy{}, appt(domain.AppointmentPending, "22:00"), false},
		{"sistem onaylı", SystemCancelPolicy{}, appt(domain.AppointmentApproved, "11:00"), false},
	}
	for _, c := range cases {
		err := c.policy.Check(c.a, now)
		if (err == nil) != c.ok {
			t.Errorf("%s: err = %v, ok bekleniyordu = %v", c.name, err, c.ok)
		}
	}
	if _, ok := (PatientCancelPolicy{}).Notification(); ok {
		t.Error("hastanın kendi iptali bildirim üretmemeli")
	}
	for _, p := range []CancelPolicy{DoctorCancelPolicy{}, AdminCancelPolicy{}, SystemCancelPolicy{}} {
		if _, ok := p.Notification(); !ok {
			t.Errorf("%T bildirim üretmeli", p)
		}
	}
}
