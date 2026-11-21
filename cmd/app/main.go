// Command app is the <name> service: a cmdguard `serve` verb over the
// go-appkit preset spine. Everything production-shaped is inherited from the
// framework — graceful drain, health + dashboard, error pages, sd_notify,
// env-switched otel/security/realtime legs — so this file stays small on
// purpose: it names the service, loads its config, and starts it.
//
// Run:
//
//	go run ./cmd/app serve
package main

import (
	"context"
	"fmt"
	"os"

	v5 "github.com/larsartmann/cmdguard/v5/pkg/cmdguard/v5"

	"github.com/example/go-service-template/internal/app"
)

func main() {
	os.Exit(v5.ExitCode(run(context.Background(), os.Args[1:])))
}

func run(ctx context.Context, args []string) error {
	cli, err := v5.NewApp(
		app.Name,
		app.Short,
		app.Config{},
		func(cli *v5.CLI[app.Config]) error {
			serve, err := v5.NewCommand(
				"serve",
				serveFlags{},
				func(ctx context.Context, _ *app.Config, _ serveFlags) error {
					cfg, err := app.Load()
					if err != nil {
						return err
					}

					return app.Serve(ctx, cfg)
				},
				v5.WithShort("start the HTTP service (blocks until SIGINT/SIGTERM)"),
				v5.WithNoArgs(),
			)
			if err != nil {
				return err
			}

			return v5.AddCommand(cli, serve)
		},
		v5.WithCLIVersion(app.Version),
		v5.WithBatteries(), // `version` + `doctor` commands, machine-readable error hints
	)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)

		return err
	}

	return cli.ExecuteWithArgs(ctx, args)
}

// serveFlags is empty on purpose: the service reads its settings from env
// (config.Load precedence flag > env > file > default). Add typed flags here
// when the CLI needs them — the tag grammar is in the cmdguard skill.
type serveFlags struct{}
