//go:build events

// Package events is the event-sourcing skeleton: a lifecycle-managed
// cqrs.EventService wired into the service's logger, DLQ on. It is
// build-tag-gated (enable with `go build -tags events`) so the default
// binary carries zero event-sourcing weight until the domain needs it —
// delete this file if the service stays CRUD.
//
// Wiring it in (inside app.Serve, behind the same tag):
//
//	events, err := events.New(cfg.LogLevel)
//	...
//	_ = events.Host().Register(myProjection)
//	_ = es.StartProjections(ctx)
//
// and a ShutdownHook flushing it (hooks pass through the preset Config).
// Full contracts: the cqrs module README.
package events

import (
	"context"
	"fmt"

	"github.com/larsartmann/go-appkit/cqrs"
)

// New builds the event service with the canonical template posture: SQLite
// DSN, projections logging into the app logger, DLQ enabled (poison events
// quarantined, not fatal). Swap Driver/DSN per deployment.
func New(_ context.Context) (*cqrs.EventService, error) {
	es, err := cqrs.NewEventService(cqrs.EventConfig{
		DSN: "events.db",
		DLQ: &cqrs.DLQConfig{},
	})
	if err != nil {
		return nil, fmt.Errorf("event service: %w", err)
	}

	return es, nil
}
