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
    let
      # The git rev the flake was evaluated at — the image's Version stamp.
      # Hoisted here because flake-parts forbids `self` as a perSystem arg.
      stamp = self.rev or self.dirtyRev or "dev";
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];

      # The docs-command smoke check: every command the living docs name must
      # run clean or carry an explicit skip reason (scripts/docs-command-smoke.sh).
      # In the sandbox we verify the cheap half — script syntax and that the
      # command inventory still matches the living docs; the executable half
      # runs locally and in CI where the network and toolchain exist.
      perSystem =
        {
          pkgs,
          self',
          lib,
          ...
        }:
        {
          # Generated templ code is the generator's, byte for byte: CI's
          # drift check diffs the committed files against raw `go tool templ
          # generate` output, so no formatter may rewrite them. treefmt's
          # goimports merges the generator's two import lines, which split
          # the committed files from every regen and kept CI red
          # (2026-11-24 to 26). vendor/* is treefmt-nix's own default
          # exclude; an explicit list replaces it, so it rides along.
          treefmt = {
            programs.gofumpt.excludes = [
              "vendor/*"
              "*_templ.go"
            ];
            programs.goimports.excludes = [
              "vendor/*"
              "*_templ.go"
            ];
          };

          checks =
            let
              docsCommandSmoke =
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
            in
            lib.mkMerge [
              { docs-command-smoke = docsCommandSmoke; }
              (lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
                # The daemonless half of the image smoke: turn the nix2container
                # spec into an OCI layout that scripts/image-smoke.sh loads
                # (as is under podman, converted to a docker archive under
                # docker). Booting needs a daemon, so it happens in CI and
                # locally. Linux-only like the image itself.
                image-smoke-archive =
                  pkgs.runCommand "image-smoke-archive"
                    {
                      nativeBuildInputs = [ pkgs.jq ];
                    }
                    ''
                      # The fleet module's copy app carries the skopeo built with the
                      # `nix:` transport; a stock skopeo rejects that transport.
                      # Parse it out of the app's PATH export so this check rides
                      # whatever skopeo the module chose — and fails loudly the day
                      # the module stops providing one.
                      skopeo_nix=$(sed -n 's#^export PATH=".*\(/nix/store/[^/]*-skopeo-[0-9.]*\)/bin.*$#\1/bin/skopeo#p' ${self'.apps.app-image-load.program} | head -1)
                      test -n "$skopeo_nix" || { echo "no nix-transport skopeo found in app-image-load"; exit 1; }
                      mkdir -p $out/tmp
                      export HOME=$out/tmp
                      # containers/image stages copy temporaries under /var/tmp by
                      # default (CONTAINERS_IMAGE_TMP), which is not writable in the
                      # build sandbox — point the copy at $out. This is why the
                      # destination is a layout and not a docker archive: skopeo's
                      # docker-archive destination hard-codes /var/tmp for its temp
                      # layer and ignores CONTAINERS_IMAGE_TMP.
                      export CONTAINERS_IMAGE_TMP=$out/tmp
                      "$skopeo_nix" --insecure-policy copy nix:${self'.packages.app-image} oci:$out/layout:app:latest
                      test -s $out/layout/index.json
                      manifest_digest=$(jq -r '.manifests[0].digest' $out/layout/index.json)
                      manifest=$out/layout/blobs/sha256/''${manifest_digest#sha256:}
                      test -s "$manifest"
                      config_digest=$(jq -r '.config.digest' "$manifest")
                      config=$out/layout/blobs/sha256/''${config_digest#sha256:}
                      test -s "$config"
                      jq -e --arg stamp '${stamp}' '
                        .architecture == "amd64"
                        and .config.Entrypoint == ["/bin/app"]
                        and .config.Cmd == ["serve"]
                        and .config.User == "65532:65532"
                        and (.config.Env | index("SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt") != null)
                        and (.config.ExposedPorts | has("8080/tcp"))
                        and .config.Labels["org.opencontainers.image.version"] == $stamp
                      ' "$config" || { echo "posture or stamp assertion failed"; exit 1; }
                      layers=$(jq '.layers | length' "$manifest")
                      diffs=$(jq '.rootfs.diff_ids | length' "$config")
                      test "$layers" -eq "$diffs" || { echo "layer/diff_id count mismatch: $layers vs $diffs"; exit 1; }
                    '';
              })
            ];
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
