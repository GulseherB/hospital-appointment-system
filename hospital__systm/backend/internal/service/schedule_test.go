package service

import (
	"strings"
	"testing"

	"hospital/backend/internal/apperr"
	"hospital/backend/internal/clock"
	"hospital/backend/internal/repository"
)

func mustTime(s string) clock.TimeOfDay {
	t, err := clock.ParseTimeOfDay(s)
	if err != nil {
		panic(err)
	}
	return t
}

func rng(day int, start, end string) repository.WeeklyRange {
	return repository.WeeklyRange{Weekday: day, Start: mustTime(start), End: mustTime(end)}
}

func TestParseRanges(t *testing.T) {
	ok, err := parseRanges([][3]string{{"13:00", "17:00"}, {"09:00", "12:00"}}, []int{1, 1}, false)
	if err != nil {
		t.Fatalf("geçerli aralıklar reddedildi: %v", err)
	}
	if ok[0].Start != mustTime("09:00") {
		t.Fatal("aralıklar sıralanmalı")
	}

	cases := []struct {
		name      string
		raw       [][3]string
		days      []int
		onePerDay bool
		want      string
	}{
		{"geçersiz gün", [][3]string{{"09:00", "10:00"}}, []int{8}, false, "gün 1"},
		{"bitiş önce", [][3]string{{"10:00", "09:00"}}, []int{1}, false, "bitiş saati başlangıçtan sonra"},
		{"eşit saat", [][3]string{{"10:00", "10:00"}}, []int{1}, false, "bitiş saati başlangıçtan sonra"},
		{"biçim", [][3]string{{"9:00", "10:00"}}, []int{1}, false, "HH:MM"},
		{"çakışma", [][3]string{{"09:00", "12:00"}, {"11:00", "13:00"}}, []int{2, 2}, false, "çakışıyor"},
		{"aynı gün iki kez", [][3]string{{"09:00", "12:00"}, {"13:00", "17:00"}}, []int{3, 3}, true, "birden fazla"},
	}
	for _, c := range cases {
		_, err := parseRanges(c.raw, c.days, c.onePerDay)
		e, isApp := apperr.As(err)
		if !isApp || e.Code != apperr.CodeInvalidRequest || !strings.Contains(e.Message, c.want) {
			t.Errorf("%s: beklenen %q içeren INVALID_REQUEST, gelen %v", c.name, c.want, err)
		}
	}

	// Bitişik aralıklar (12:00 bitiş, 12:00 başlangıç) çakışma sayılmaz.
	if _, err := parseRanges([][3]string{{"09:00", "12:00"}, {"12:00", "13:00"}}, []int{1, 1}, false); err != nil {
		t.Fatalf("bitişik aralıklar kabul edilmeli: %v", err)
	}
}

func TestRangesWithin(t *testing.T) {
	hours := []repository.WeeklyRange{rng(1, "09:00", "17:00"), rng(2, "09:00", "13:00")}
	if msg := rangesWithin([]repository.WeeklyRange{rng(1, "09:00", "17:00"), rng(2, "10:00", "12:00")}, hours); msg != "" {
		t.Fatalf("içerideki aralık reddedildi: %s", msg)
	}
	if msg := rangesWithin([]repository.WeeklyRange{rng(1, "08:30", "12:00")}, hours); !strings.Contains(msg, "dışında") {
		t.Fatalf("dışarıdaki aralık kabul edildi: %q", msg)
	}
	if msg := rangesWithin([]repository.WeeklyRange{rng(6, "10:00", "12:00")}, hours); !strings.Contains(msg, "kapalı") {
		t.Fatalf("kapalı gün kabul edildi: %q", msg)
	}
}
