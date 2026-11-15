package service

import (
	"sort"
	"time"

	"hospital/backend/internal/clock"
	"hospital/backend/internal/repository"
)

// Slot kuralları (API sözleşmesi → Slot kuralları).
const (
	SlotGridMinutes    = 15                       // başlangıçlar :00, :15, :30, :45
	MinBookingLead     = 24 * time.Hour           // başlangıcına 24 saatten az kalan slot listelenmez
	BookingHorizonDays = 7                        // bugünden itibaren en fazla 7 gün sonrası
	LunchStart         = clock.TimeOfDay(12 * 60) // 12:00
	LunchEnd           = clock.TimeOfDay(13 * 60) // 13:00
)

// DoctorSchedule, slot üretimi için bir doktorun haftalık uygunluğu ve dolu aralıklarıdır.
type DoctorSchedule struct {
	DoctorID     int64
	DoctorName   string
	Availability []repository.WeeklyRange
	Busy         []repository.Interval
}

// Slot, üretilen randevu aralığıdır.
type Slot struct {
	DoctorID   int64
	DoctorName string
	Start      time.Time
	End        time.Time
}

// SlotRequest, slot üretiminin girdisidir. Tarihler gün olarak (saat önemsiz) ve dahil olarak yorumlanır.
type SlotRequest struct {
	Now          time.Time
	DateFrom     time.Time
	DateTo       time.Time
	DurationMin  int
	WorkingHours []repository.WeeklyRange // şubenin saatleri (gün başına bir aralık)
	Doctors      []DoctorSchedule
}

func startOfDay(t time.Time) time.Time {
	y, m, d := t.In(clock.Location).Date()
	return time.Date(y, m, d, 0, 0, 0, 0, clock.Location)
}

// BookingWindow, randevu alınabilecek ilk an ve son günün ertesi gece yarısıdır (hariç).
func BookingWindow(now time.Time) (earliest, end time.Time) {
	return now.Add(MinBookingLead), startOfDay(now).AddDate(0, 0, BookingHorizonDays+1)
}

// overlapsLunch, gün içi [start, end) aralığı 12:00–13:00 ile kesişiyor mu.
func overlapsLunch(start, end clock.TimeOfDay) bool {
	return start < LunchEnd && end > LunchStart
}

func overlapsAny(start, end time.Time, busy []repository.Interval) bool {
	for _, b := range busy {
		if start.Before(b.End) && end.After(b.Start) {
			return true
		}
	}
	return false
}

// GenerateSlots, kurallara uyan boş slotları tarih-saat sırasıyla üretir.
// Doktorun uygunluğu ile şubenin o günkü saatlerinin kesişimi 15 dakikalık ızgarada taranır;
// öğle arasıyla kesişen, 24 saatten yakın, 7 gün ufkunun dışındaki ve dolu aralıklarla çakışan slotlar atlanır.
func GenerateSlots(req SlotRequest) []Slot {
	if req.DurationMin <= 0 {
		return nil
	}
	earliest, horizonEnd := BookingWindow(req.Now)
	day := startOfDay(req.DateFrom)
	if today := startOfDay(req.Now); day.Before(today) {
		day = today
	}
	last := startOfDay(req.DateTo)

	hoursByDay := map[int]repository.WeeklyRange{}
	for _, h := range req.WorkingHours {
		hoursByDay[h.Weekday] = h
	}
	duration := clock.TimeOfDay(req.DurationMin)

	var slots []Slot
	for ; !day.After(last) && day.Before(horizonEnd); day = day.AddDate(0, 0, 1) {
		weekday := clock.ISOWeekday(day)
		hours, open := hoursByDay[weekday]
		if !open {
			continue
		}
		for _, doc := range req.Doctors {
			for _, a := range doc.Availability {
				if a.Weekday != weekday {
					continue
				}
				from, to := max(a.Start, hours.Start), min(a.End, hours.End)
				// İlk başlangıç ızgaraya yuvarlanır (ör. 09:10 → 09:15).
				first := (from + SlotGridMinutes - 1) / SlotGridMinutes * SlotGridMinutes
				for t := first; t+duration <= to; t += SlotGridMinutes {
					if overlapsLunch(t, t+duration) {
						continue
					}
					start := t.On(day)
					end := start.Add(time.Duration(req.DurationMin) * time.Minute)
					if start.Before(earliest) || !start.Before(horizonEnd) || overlapsAny(start, end, doc.Busy) {
						continue
					}
					slots = append(slots, Slot{DoctorID: doc.DoctorID, DoctorName: doc.DoctorName, Start: start, End: end})
				}
			}
		}
	}
	sort.SliceStable(slots, func(i, j int) bool {
		if !slots[i].Start.Equal(slots[j].Start) {
			return slots[i].Start.Before(slots[j].Start)
		}
		if slots[i].DoctorName != slots[j].DoctorName {
			return slots[i].DoctorName < slots[j].DoctorName
		}
		return slots[i].DoctorID < slots[j].DoctorID
	})
	return slots
}
