// Package httpapi, REST uç noktalarını, ara katmanları ve JSON yanıtlarını içerir.
package httpapi

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"unicode/utf8"

	"hospital/backend/internal/apperr"
)

const maxBodyBytes = 1 << 20 // 1 MB

type errorBody struct {
	Error struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

// writeJSON, değeri JSON olarak yazar.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if v != nil {
		if err := json.NewEncoder(w).Encode(v); err != nil {
			log.Printf("yanıt yazılamadı: %v", err)
		}
	}
}

// listResponse, sözleşmedeki liste biçimidir: {"items": [...]}.
func listResponse[T any](items []T) map[string]any {
	if items == nil {
		items = []T{}
	}
	return map[string]any{"items": items}
}

// writeError, hatayı sözleşmedeki biçimde yazar. Bilinmeyen hatalar loglanır ve 500 döner.
func writeError(w http.ResponseWriter, r *http.Request, err error) {
	e, ok := apperr.As(err)
	if !ok {
		log.Printf("HATA %s %s: %v", r.Method, r.URL.Path, err)
		e = apperr.Internal()
	}
	var body errorBody
	body.Error.Code = e.Code
	body.Error.Message = e.Message
	writeJSON(w, e.Status, body)
}

// decodeJSON, gövdeyi okur. Geçersiz UTF-8, bilinmeyen alanlar ve birden fazla JSON nesnesi reddedilir.
// (encoding/json geçersiz UTF-8'i sessizce "�" ile değiştirir; Türkçe karakterlerin bozuk kaydedilmemesi için önce denetlenir.)
func decodeJSON(r *http.Request, dst any) error {
	body, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, maxBodyBytes))
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			return apperr.InvalidRequest("İstek gövdesi çok büyük.")
		}
		return apperr.InvalidRequest("İstek gövdesi okunamadı.")
	}
	if !utf8.Valid(body) {
		return apperr.InvalidRequest("İstek gövdesi UTF-8 kodlamasında olmalıdır.")
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		var syntaxErr *json.SyntaxError
		var typeErr *json.UnmarshalTypeError
		switch {
		case errors.Is(err, io.EOF):
			return apperr.InvalidRequest("İstek gövdesi boş.")
		case errors.As(err, &syntaxErr):
			return apperr.InvalidRequest("İstek gövdesi geçerli JSON değil.")
		case errors.As(err, &typeErr):
			return apperr.InvalidRequest("'" + typeErr.Field + "' alanının türü hatalı.")
		case strings.HasPrefix(err.Error(), "json: unknown field "):
			return apperr.InvalidRequest("Tanımsız alan: " + strings.TrimPrefix(err.Error(), "json: unknown field ") + ".")
		case errors.Is(err, io.ErrUnexpectedEOF):
			return apperr.InvalidRequest("İstek gövdesi geçerli JSON değil.")
		default:
			return apperr.InvalidRequest("İstek gövdesi okunamadı: " + err.Error())
		}
	}
	if dec.More() {
		return apperr.InvalidRequest("İstek gövdesinde tek bir JSON nesnesi olmalıdır.")
	}
	return nil
}

// pathID, yol parametresini pozitif tamsayı olarak okur.
func pathID(r *http.Request, name string) (int64, error) {
	id, err := strconv.ParseInt(r.PathValue(name), 10, 64)
	if err != nil || id <= 0 {
		return 0, apperr.InvalidRequest("Geçersiz kimlik: " + name)
	}
	return id, nil
}
