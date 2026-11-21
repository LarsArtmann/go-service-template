// Package app wires the service: config via the config module, the HTTP
// service via the preset spine, routes via internal/api. This is the whole
// composition root — keep it this small.
package app

import (
	"context"
	"fmt"

	"github.com/larsartmann/go-appkit/config"
	appkit "github.com/larsartmann/go-appkit"
	appkitpreset "github.com/larsartmann/go-appkit/preset"

	"github.com/example/go-service-template/internal/api"
	"github.com/example/go-service-template/views"
)

// Name is the service identity — rename it (and the module path) when
// scaffolding a real service from this template.
const (
	Name  = "app"
	Short = "the <name> service (scaffolded from go-service-template)"
)

// Version is stamped at build time: -ldflags "-X .../internal/app.Version=v1.2.3".
var Version = "dev"

// Config is the service's own settings (NOT the framework's — the preset
// legs are env-switched, see the preset README grammar table).
type Config struct {
	Addr     string `default:":8080" env:"APP_ADDR"`
	LogLevel string `default:"info" env:"APP_LOG_LEVEL"`
}

// Load resolves the config through the config module (precedence
// flag > env > file > default; one Rejection naming every bad field).
// Add config.WithFile("app.yaml") when the service gains a file layer.
func Load() (*Config, error) {
	return config.Load[Config]()
}

// Serve is the composition root: build the preset spine, register routes,
// block on Run. Signal handling belongs to the core Run — SIGINT/SIGTERM
// trigger the full graceful drain (ready-flip → DrainHooks → drain wait →
// listener close → ShutdownHooks).
func Serve(ctx context.Context, cfg *Config) error {
	svc, err := appkitpreset.New(appkitpreset.Config{
		Addr:     cfg.Addr,
		LogLevel: appkit.LogLevel(cfg.LogLevel),
		Version:  Version,
	})
	if err != nil {
		return fmt.Errorf("build service: %w", err)
	}
	defer func() { _ = svc.Close() }()

	api.Register(svc.Mux, api.Deps{Version: Version})

	if err := views.Mount(svc.Mux, Version); err != nil {
		return fmt.Errorf("mount views: %w", err)
	}

	return svc.Run(ctx)
}
