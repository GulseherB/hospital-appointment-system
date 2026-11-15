package service

import (
	"fmt"
	"sort"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/clock"
	"hospital/backend/internal/repository"
)

var weekdayNames = [...]string{"", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"}

// WeekdayName, 1–7 arası gün numarasının Türkçe adı.
func WeekdayName(day int) string {
	if day < 1 || day > 7 {
		return fmt.Sprintf("gün %d", day)
	}
	return weekdayNames[day]
}

// parseRanges, API'den gelen saat aralıklarını çözer ve doğrular:
// gün 1–7, HH:MM biçimi, bitiş > başlangıç; onePerDay true ise her gün en fazla bir kez,
// değilse aynı gündeki aralıklar çakışamaz.
func parseRanges(raw [][3]string, weekdays []int, onePerDay bool) ([]repository.WeeklyRange, error) {
	ranges := make([]repository.WeeklyRange, 0, len(raw))
	for i, r := range raw {
		day := weekdays[i]
		if day < 1 || day > 7 {
			return nil, apperr.InvalidRequest(fmt.Sprintf("%d. satır: gün 1 (Pazartesi) ile 7 (Pazar) arasında olmalıdır.", i+1))
		}
		start, err := clock.ParseTimeOfDay(r[0])
		if err != nil {
			return nil, apperr.InvalidRequest(fmt.Sprintf("%s: başlangıç saati HH:MM biçiminde olmalıdır.", WeekdayName(day)))
		}
		end, err := clock.ParseTimeOfDay(r[1])
		if err != nil {
			return nil, apperr.InvalidRequest(fmt.Sprintf("%s: bitiş saati HH:MM biçiminde olmalıdır.", WeekdayName(day)))
		}
		if end <= start {
			return nil, apperr.InvalidRequest(fmt.Sprintf("%s: bitiş saati başlangıçtan sonra olmalıdır.", WeekdayName(day)))
		}
		ranges = append(ranges, repository.WeeklyRange{Weekday: day, Start: start, End: end})
	}

	sort.Slice(ranges, func(i, j int) bool {
		if ranges[i].Weekday != ranges[j].Weekday {
			return ranges[i].Weekday < ranges[j].Weekday
		}
		return ranges[i].Start < ranges[j].Start
	})
	for i := 1; i < len(ranges); i++ {
		prev, cur := ranges[i-1], ranges[i]
		if prev.Weekday != cur.Weekday {
			continue
		}
		if onePerDay {
			return nil, apperr.InvalidRequest(WeekdayName(cur.Weekday) + " günü birden fazla kez girilmiş.")
		}
		if cur.Start < prev.End {
			return nil, apperr.InvalidRequest(fmt.Sprintf("%s: %s–%s ile %s–%s aralıkları çakışıyor.",
				WeekdayName(cur.Weekday), prev.Start, prev.End, cur.Start, cur.End))
		}
	}
	return ranges, nil
}

// rangesWithin, her aralığın aynı gündeki çalışma saatinin içinde olup olmadığını denetler.
// İlk uymayan aralık için Türkçe açıklama döndürür; hepsi uyuyorsa boş metin.
func rangesWithin(items, hours []repository.WeeklyRange) string {
	byDay := map[int]repository.WeeklyRange{}
	for _, h := range hours {
		byDay[h.Weekday] = h
	}
	for _, r := range items {
		h, open := byDay[r.Weekday]
		if !open {
			return fmt.Sprintf("%s günü şube kapalı; %s–%s uygunluğu girilemez.", WeekdayName(r.Weekday), r.Start, r.End)
		}
		if r.Start < h.Start || r.End > h.End {
			return fmt.Sprintf("%s %s–%s aralığı, şubenin çalışma saatleri (%s–%s) dışında.",
				WeekdayName(r.Weekday), r.Start, r.End, h.Start, h.End)
		}
	}
	return ""
}

func toWorkingHoursItems(ranges []repository.WeeklyRange) []WorkingHoursItem {
	items := make([]WorkingHoursItem, 0, len(ranges))
	for _, r := range ranges {
		items = append(items, WorkingHoursItem{Weekday: r.Weekday, OpensAt: r.Start.String(), ClosesAt: r.End.String()})
	}
	return items
}

func toAvailabilityItems(ranges []repository.WeeklyRange) []AvailabilityItem {
	items := make([]AvailabilityItem, 0, len(ranges))
	for _, r := range ranges {
		items = append(items, AvailabilityItem{Weekday: r.Weekday, StartTime: r.Start.String(), EndTime: r.End.String()})
	}
	return items
}
