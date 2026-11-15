package httpapi

import (
	"net/http/httptest"
	"strings"
	"testing"

	"hospital/backend/internal/apperr"
)

type sample struct {
	Name string `json:"name"`
}

func decode(body string) (sample, error) {
	var s sample
	r := httptest.NewRequest("POST", "/", strings.NewReader(body))
	err := decodeJSON(r, &s)
	return s, err
}

func TestDecodeJSON(t *testing.T) {
	s, err := decode(`{"name":"Kadıköy Şubesi"}`)
	if err != nil || s.Name != "Kadıköy Şubesi" {
		t.Fatalf("Türkçe karakterli geçerli gövde okunamadı: %q %v", s.Name, err)
	}

	cases := map[string]string{
		"boş":            ``,
		"bozuk":          `{"name":`,
		"tanımsız alan":  `{"nam":"x"}`,
		"tür hatası":     `{"name":5}`,
		"iki nesne":      `{"name":"a"}{"name":"b"}`,
		"geçersiz UTF-8": "{\"name\":\"Kad\xfdk\xf6y\"}", // Windows-1254 baytları
	}
	for name, body := range cases {
		_, err := decode(body)
		e, ok := apperr.As(err)
		if !ok || e.Code != apperr.CodeInvalidRequest {
			t.Errorf("%s: INVALID_REQUEST beklendi, gelen %v", name, err)
		}
	}

	big := `{"name":"` + strings.Repeat("a", maxBodyBytes) + `"}`
	if _, err := decode(big); err == nil || !strings.Contains(err.Error(), "çok büyük") {
		t.Errorf("büyük gövde reddedilmeli: %v", err)
	}
}
