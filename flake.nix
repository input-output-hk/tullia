{
  description = "Tullia - the hero Cicero deserves";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    nix2container.url = "github:nlewo/nix2container";
    std.url = "github:divnix/std";
    nix-nomad = {
      url = "github:tristanpemble/nix-nomad";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-lib.follows = "nixpkgs";
        flake-utils.follows = "nix2container/flake-utils";
      };
    };
  };

  outputs = inputs: let
    tasks = import ./nix/std.nix inputs;
    doc = import ./nix/doc.nix inputs;
    lib = import ./nix/lib.nix inputs;
  in
    inputs.std.growOn {
      inherit inputs;
      cellsFrom = ./cells;
      cellBlocks = [
        (inputs.std.functions "library")
        (inputs.std.devshells "devshell")
        (inputs.std.installables "apps")
        # dog food
        (tasks "task")
        (inputs.std.functions "action")
      ];
    }
    # Soil ...
    # nix-cli compat
    {
      devShells = inputs.std.harvest inputs.self ["tullia" "devshell"];
      packages = inputs.std.harvest inputs.self ["tullia" "apps"];
    }
    # dog food
    (lib.fromStd {
      actions = inputs.std.harvest inputs.self ["tullia" "action"];
      tasks = inputs.std.harvest inputs.self ["tullia" "task"];
    })
    # top level tullia outputs
    lib
    {
      inherit tasks doc;
      flakePartsModules = import nix/flakePartsModules.nix lib;
    };
}
