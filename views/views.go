// Package views mounts the templ pages. Pretty 404/405 come from the
// preset's errorpages spine — this package only adds real pages.
package views

import (
	"net/http"

	"github.com/a-h/templ"
)

// Mount registers every page on the service mux.
func Mount(mux *http.ServeMux, version string) error {
	mux.Handle("GET /{$}", templ.Handler(hello(version)))

	return nil
}
