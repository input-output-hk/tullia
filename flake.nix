{
  description = "Tullia - the hero Cicero deserves";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix2container.url = "github:nlewo/nix2container";
    std.url = "github:divnix/std";
  };

  outputs = inputs: let
    pp = a: pp2 a a;
    pp2 = a: b: builtins.trace (builtins.toJSON a) b;
    cicero = name: {
      inherit name;
      clade = "cicero";
      actions = {
        system,
        flake,
        fragment,
        fragmentRelPath,
        cell,
      }: let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;
        escape = lib.escapeShellArg;
        fragmentParts = lib.splitString "/" fragmentRelPath;
        name = lib.last fragmentParts;
        organelle = lib.elemAt fragmentParts (lib.length fragmentParts - 2);

        tulliaFlake = inputs.self;
        tullia = inputs.self.defaultPackage.${system};

        n2cFlake = inputs.nix2container;
        n2c = n2cFlake.packages.${system}.nix2container;
        inherit (n2c) buildImage;

        evaluated =
          (lib.evalModules {
            modules = [
              {
                _module.args = {
                  pkgs = pkgs // {inherit tullia buildImage;};
                  rootDir = flake;
                };
                task = cell.${organelle};
              }
              (tulliaFlake + /nix/module.nix)
            ];
          })
          .config;

        dag = evaluated.dag;
        nsjails =
          lib.mapAttrs (
            n: v: let
              g = evaluated.generatedTask."tullia-${n}";
            in "${g.nsjail.run}/bin/tullia-${n}-nsjail"
          )
          evaluated.task;

        spec = lib.escapeShellArg (builtins.toJSON {
          dag = {"${name}" = [];};
          bin = nsjails;
        });
      in [
        {
          name = "nsjail";
          description = "run this task in nsjail";
          command =
            []
            ++ ["go" "run" "./cli"]
            ++ ["--run-spec" spec]
            ++ ["--mode" "passthrough"]
            ++ ["--runtime" "nsjail"]
            ++ [(lib.escapeShellArg name)];
        }
      ];
    };
    # {
    #   name = "nsjail";
    #   description = "run this task in nsjail";
    #   command = ["${task.nsjail.run}/bin/tullia-${name}-nsjail"];
    # }
    # {
    #   name = "podman";
    #   description = "run this task in podman";
    #   command = ["${task.podman.run}/bin/tullia-${name}-podman"];
    # }
  in
    inputs.std.growOn {
      inherit inputs;
      cellsFrom = ./cells;
      organelles = [
        (inputs.std.functions "library")
        (cicero "task")
        (inputs.std.devshells "devshell")
        (inputs.std.installables "apps")
      ];
    }
    (
      let
        gather = f: inputs.nixpkgs.lib.mapAttrs (n: v: f v) inputs.self;
      in {
        devShell = gather (v: v.tullia.devshell.default);
        # task = gather (v: v.tullia.library.task);
        # dag = gather (v: v.tullia.library.dag);
        defaultPackage = gather (v: v.tullia.apps.tullia);
      }
    );
}
