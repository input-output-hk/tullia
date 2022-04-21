{
  description = "Cicero Library";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    utils.url = "github:kreisys/flake-utils";
    nix.url = "github:NixOS/nix/2.8.0";
    nix2container.url = "github:nlewo/nix2container";
  };

  outputs = {
    self,
    nixpkgs,
    utils,
    nix,
    nix2container,
    ...
  } @ inputs:
    (utils.lib.eachSystem ["x86_64-linux"] (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            nix = nix.packages.${system}.nix;
            inherit (nix2container.packages.x86_64-linux.nix2container) buildImage buildLayer pullImage;
            skopeo = nix2container.packages.x86_64-linux.skopeo-nix2container;
            nsjail = prev.nsjail.overrideAttrs (o: {
              version = "3.1";
              src = prev.fetchFromGitHub {
                owner = "google";
                repo = "nsjail";
                rev = "3.1";
                fetchSubmodules = true;
                sha256 = "sha256-ICJpD7iCT7tLRX+52XvayOUuO1g0L0jQgk60S2zLz6c=";
              };
              patches = [];
            });
          })
        ];
      };
    in {
      devShell = with pkgs;
        mkShell {
          nativeBuildInputs = [
            alejandra
            go
            gocode
            golangci-lint
            gopls
            gotools
            nix
            nsjail
          ];
        };
    }))
    // rec {
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            nix = nix.packages.${system}.nix;
            inherit (nix2container.packages.x86_64-linux.nix2container) buildImage buildLayer pullImage;
            skopeo = nix2container.packages.x86_64-linux.skopeo-nix2container;
            nsjail = prev.nsjail.overrideAttrs (o: {
              version = "3.1";
              src = prev.fetchFromGitHub {
                owner = "google";
                repo = "nsjail";
                rev = "3.1";
                fetchSubmodules = true;
                sha256 = "sha256-ICJpD7iCT7tLRX+52XvayOUuO1g0L0jQgk60S2zLz6c=";
              };
              patches = [];
            });
          })
        ];
      };

      lib = import ./nix/lib.nix {
        inherit pkgs;
      };

      nixosModules.tullia = import ./nix/module.nix;

      ciceroActions = lib.evalActions [./nix/ci.nix];
    };
}
