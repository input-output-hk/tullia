{
  description = "Tullia - the hero Cicero deserves";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix2container.url = "github:nlewo/nix2container/init-nix-db";
    std.url = "github:divnix/std";
  };

  outputs = inputs: let
    tasks = import ./nix/std.nix inputs;
    lib = import ./nix/lib.nix inputs;
  in
    inputs.std.growOn {
      inherit inputs;
      cellsFrom = ./cells;
      organelles = [
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
      devShell = inputs.std.harvest inputs.self ["tullia" "devshell" "default"];
      defaultPackage = inputs.std.harvest inputs.self ["tullia" "apps" "tullia"];
    }
    # dog food
    (lib.fromStd {
      actions = inputs.std.harvest inputs.self ["tullia" "action"];
      tasks = inputs.std.harvest inputs.self ["tullia" "task"];
    })
    # top level tullia outputs
    (lib // {inherit tasks;});
}
