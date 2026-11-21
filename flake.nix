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
        # Filled by the first `nix build` (it prints the real hash); see
        # vendorHash.nix.
        vendorHash = import ./vendorHash.nix;
        subPackages = [ "./cmd/app" ];
      };
    };
}
