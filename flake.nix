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

    mkCicero = name: {
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
        cmd = pkgs.writeShellApplication {
          name = "cmd";
          text = ''
            echo name: ${lib.escapeShellArg name}
            echo system: ${lib.escapeShellArg system}
            echo flake: ${lib.escapeShellArg flake}
            echo fragment: ${lib.escapeShellArg fragment}
            echo fragmentRelPath: ${lib.escapeShellArg fragmentRelPath}
            echo ${lib.escapeShellArg (__toJSON (__attrNames cell.${name}))}
          '';
        };
        command = ["${cmd}/bin/cmd"];
        dbg = [
          {
            name = "print";
            description = "print";
            inherit command;
          }
        ];
      in [];
    };

    mkTullia = name: {
      inherit name;
      clade = "tullia";
      actions = {
        system,
        flake,
        fragment,
        fragmentRelPath,
        cell,
      }: let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;
        fragmentParts = lib.splitString "/" fragmentRelPath;
        taskName = lib.last fragmentParts;
        tullia = inputs.self.defaultPackage.${system};

        evaluated =
          (lib.evalModules {
            modules = [
              {
                _module.args = {
                  pkgs =
                    pkgs
                    // {
                      tullia = inputs.self.defaultPackage.${system};
                      inherit (inputs.nix2container.packages.${system}.nix2container) buildImage;
                    };
                  rootDir = flake;
                };
                task = cell.${name};
              }
              (inputs.self + /nix/module.nix)
            ];
          })
          .config;

        mkSpec = runtime: let
          inherit (evaluated.generatedTask."tullia-${taskName}".${runtime}) run;
        in (lib.escapeShellArg (builtins.toJSON {
          dag = {"${taskName}" = [];};
          bin = {${taskName} = "${run}/bin/tullia-${taskName}-${runtime}";};
        }));

        mkAction = runtime: {
          name = runtime;
          description = "run this task in ${runtime}";
          command =
            []
            ++ ["go" "run" "./cli"]
            ++ ["--run-spec" (mkSpec runtime)]
            ++ ["--mode" "passthrough"]
            ++ ["--runtime" runtime]
            ++ [(lib.escapeShellArg taskName)];
        };

        nsjailSpec = mkSpec "nsjail";
        podmanSpec = mkSpec "podman";
      in
        map mkAction ["nsjail" "podman"];
    };
  in
    inputs.std.growOn {
      inherit inputs;
      cellsFrom = ./cells;
      organelles = [
        (inputs.std.functions "library")
        (mkTullia "task")
        (mkCicero "action")
        (inputs.std.devshells "devshell")
        (inputs.std.installables "apps")
      ];
    }
    {
      devShell = inputs.std.harvest inputs.self ["tullia" "devshell" "default"];
      defaultPackage = inputs.std.harvest inputs.self ["tullia" "apps" "tullia"];
    };
}
