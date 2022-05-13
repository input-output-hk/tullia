{
  description = "Tullia - the hero Cicero deserves";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix2container.url = "github:nlewo/nix2container";
    std.url = "github:divnix/std";
  };

  outputs = inputs: let
    mkTullia = import ./nix/std.nix inputs;
  in
    (inputs.std.growOn {
        inherit inputs;
        cellsFrom = ./cells;
        organelles = [
          (inputs.std.functions "library")
          (mkTullia "task")
          (inputs.std.functions "action")
          (inputs.std.devshells "devshell")
          (inputs.std.installables "apps")
        ];
      }
      {
        devShell = inputs.std.harvest inputs.self ["tullia" "devshell" "default"];
        defaultPackage = inputs.std.harvest inputs.self ["tullia" "apps" "tullia"];
      })
    // ((import ./nix/lib.nix inputs).fromStd {
        actions = inputs.std.harvest inputs.self ["tullia" "action"];
        tasks = inputs.std.harvest inputs.self ["tullia" "task"];
      }
      // (import ./nix/lib.nix inputs));
}
