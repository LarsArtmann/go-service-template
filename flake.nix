{
  description = "the <name> service — scaffolded from go-service-template (go-appkit preset spine)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # The fleet's Go build standard: packages, devShells, treefmt, templ
    # codegen — see github.com/LarsArtmann/go-nix-helpers.
    go-nix-helpers = {
      url = "github:LarsArtmann/go-nix-helpers";
      inputs.nixpkgs.follows = "nixpkgs";
      # Keep one lock entry per upstream (flake.lock duplicate-pin WARN).
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];

      # The docs-command smoke check: every command the living docs name must
      # run clean or carry an explicit skip reason (scripts/docs-command-smoke.sh).
      # In the sandbox we verify the cheap half — script syntax and that the
      # command inventory still matches the living docs; the executable half
      # runs locally and in CI where the network and toolchain exist.
      perSystem =
      { pkgs, ... }:
      {
        checks.docs-command-smoke =
        pkgs.runCommand "docs-command-smoke"
          {
          nativeBuildInputs = [ pkgs.bash ];
          }
          ''
          # Store-path sources keep their hash-prefixed basenames on a
          # multi-arg cp, so each copy names its destination explicitly.
          cp ${./README.md} ./README.md
          cp ${./AGENTS.md} ./AGENTS.md
          cp ${./CONTRIBUTING.md} ./CONTRIBUTING.md
          cp ${./FEATURES.md} ./FEATURES.md
          cp ${./TODO_LIST.md} ./TODO_LIST.md
          cp ${./ROADMAP.md} ./ROADMAP.md
          cp ${./CHANGELOG.md} ./CHANGELOG.md
          mkdir -p docs && cp ${./docs/DOMAIN_LANGUAGE.md} ./docs/DOMAIN_LANGUAGE.md
          DOCS_DIR=. bash ${./scripts/docs-command-smoke.sh} --self-test || {
            echo "docs-command smoke self-test failed"
            exit 1
          }
          touch $out
          '';
      };

      go-standard = {
        pname = "app";
        description = "the <name> service";
        goPkgAttr = "go_1_27";
        # The go.mod floor (1.27.4) is ABOVE nixpkgs' go_1_27 (1.27.3) — the
        # recorded fleet drift. go-standard builds the exact toolchain from
        # the go.dev source tarball instead of failing the eval:
        # bump the version here AND the hash in goTarballHash.nix on every
        # appkit floor train (a stale hash fails the fetch loudly).
        goTarballVersion = "1.27.4";
        goTarballHash = import ./goTarballHash.nix;
        # Filled by the first `nix build` (it prints the real hash); see
        # vendorHash.nix.
        vendorHash = import ./vendorHash.nix;
        subPackages = [ "./cmd/app" ];

        # Stamp internal/app.Version (read by /version + appkit_build_info)
        # with the git revision — the old Dockerfile -X flag, now here.
        ldflags = [
          "-s"
          "-w"
          "-X github.com/example/go-service-template/internal/app.Version=${
            self.rev or self.dirtyRev or "dev"
          }"
        ];

        # OCI image built from Nix (nix2container, auto-wired by the
        # composite module — no extra flake input): non-root 65532:65532,
        # cacert included, content-hash tag. Linux-only outputs:
        # packages.app-image, apps.app-image-load / app-image-push,
        # checks.<system>.container-structure.
        container = {
          enable = true;
          cmd = [ "serve" ];
          exposedPorts = [ "8080/tcp" ];
        };
      };
    };
}
