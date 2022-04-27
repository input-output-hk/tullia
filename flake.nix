{
  description = "Tullia - the hero Cicero deserves";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    utils.url = "github:kreisys/flake-utils";
    nix.url = "github:NixOS/nix/2.8.0";
    nix2container.url = "github:nlewo/nix2container";
    inclusive.url = "github:input-output-hk/nix-inclusive";
  };

  outputs = {
    self,
    nixpkgs,
    utils,
    nix,
    nix2container,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        (final: prev: {
          nix = nix.packages.${system}.nix;
          inherit (nix2container.packages.x86_64-linux.nix2container) buildImage buildLayer pullImage;
          skopeo = nix2container.packages.x86_64-linux.skopeo-nix2container;
          tullia = prev.callPackage ./nix/package.nix {flake = self;};
        })
      ];
    };

    devShell = with pkgs;
      mkShell {
        nativeBuildInputs = [
          alejandra
          go
          gocode
          golangci-lint
          gopls
          gotools
          pkgs.nix
          nsjail
          ruby
          gcc
        ];
      };

    lib = import ./nix/lib.nix {inherit pkgs devShell;};
  in
    (utils.lib.eachSystem ["x86_64-linux"] (system: let
    in {
      inherit devShell;
      inherit (lib.evalTasks [./nix/ci.nix]) dag task;
      defaultPackage = pkgs.tullia;
    }))
    // {
      nixosModules.tullia = import ./nix/module.nix;
      ciceroActions = lib.evalActions [./nix/ci.nix];
    };
}
