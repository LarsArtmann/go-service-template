// Package api owns the service's JSON routes. The example handler is the
// httpx return-(T, error) shape: nil error → JSON 200, classified error →
// the no-leak error contract (same taxonomy as the preset's error pages).
package api

import (
	"net/http"

	"github.com/larsartmann/go-appkit/httpx"
)

// Deps carries what handlers need. Keep it explicit — no package globals.
type Deps struct {
	Version string
}

type statusResponse struct {
	Status  string `json:"status"`
	Version string `json:"version"`
}

// Register mounts every route. Pattern strings are ServeMux patterns —
// method + path; unmatched paths fall through to the preset's pretty 404.
func Register(mux *http.ServeMux, deps Deps) {
	mux.Handle("GET /api/status", httpx.ResultHandler(
		func(_ *httpx.Context) (*statusResponse, error) {
			return &statusResponse{Status: "ok", Version: deps.Version}, nil
		},
	))
}
