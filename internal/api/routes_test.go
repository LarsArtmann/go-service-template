package api_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/example/go-service-template/internal/api"
)

func TestRegister_StatusRouteServesJSON(t *testing.T) {
	t.Parallel()

	mux := http.NewServeMux()
	api.Register(mux, api.Deps{Version: "test-1.2.3"})

	rec := httptest.NewRecorder()

	mux.ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/api/status", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body: %s", rec.Code, rec.Body.String())
	}

	var got struct {
		Status  string `json:"status"`
		Version string `json:"version"`
	}

	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if got.Status != "ok" || got.Version != "test-1.2.3" {
		t.Errorf("payload = %+v, want {ok test-1.2.3}", got)
	}
}

func TestRegister_UnmatchedPathFallsThrough(t *testing.T) {
	t.Parallel()

	mux := http.NewServeMux()
	api.Register(mux, api.Deps{})

	rec := httptest.NewRecorder()

	mux.ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/nope", nil))

	if rec.Code != http.StatusNotFound {
		t.Errorf("unmatched path status = %d, want 404 (pretty rendering is the errorpages spine)", rec.Code)
	}
}
