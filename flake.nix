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
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.go-nix-helpers.flakeModules.go-standard ];

      go-standard = {
        pname = "app";
        description = "the <name> service";
        goPkgAttr = "go_1_27";
        # The go.mod floor (1.27.4) is ABOVE nixpkgs' go_1_27 (1.27.3) — the
        # recorded fleet drift. go-standard builds the exact toolchain from
        # the go.dev source tarball instead of failing the eval:
        # bump BOTH lines on every appkit floor train.
        goTarballVersion = "1.27.4";
        goTarballHash = "sha256-c8+4VxrsDAEXdofbhxY9Rqog6XeWcncokaoXZU2aYJk=";
        # Filled by the first `nix build` (it prints the real hash); see
        # vendorHash.nix.
        vendorHash = import ./vendorHash.nix;
        subPackages = [ "./cmd/app" ];
      };
    };
}
