inputs: name: {
  inherit name;
  type = "tullia";
  actions = {
    system,
    target,
    fragment,
    fragmentRelPath,
  }: let
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    mkCommand = system: type: args:
      args
      // {
        command = pkgs.writeShellScript "${type}-${args.name}" args.command;
      };
    inherit (pkgs) lib;
    fragmentParts = lib.splitString "/" fragmentRelPath;
    taskName = lib.last fragmentParts;
    tullia = inputs.self.packages.${system}.default;

    runner = runtime:
      pkgs.writeShellApplication {
        name = "run-${taskName}";
        runtimeInputs = [tullia];
        text = ''
          nix build --no-link .#tullia.${system}.wrappedTask.${taskName}.${runtime}.run
          tullia run ${lib.escapeShellArg taskName} \
            ${toString (lib.cli.toGNUCommandLine {} {
            task-flake = ".#tullia.${system}.wrappedTask";
            dag-flake = ".#tullia.${system}.dag";
            mode = "passthrough";
            runtime = runtime;
          })}
        '';
      };

    mkAction = runtime: (mkCommand system "task" {
      name = runtime;
      description = "run this task in ${runtime}";
      command = "${runner runtime}/bin/run-${taskName}";
    });

    nsjailSpec = mkAction "nsjail";
    podmanSpec = mkAction "podman";

    actions = map mkAction ["nsjail" "podman"];
  in
    actions
    ++ [
      (mkCommand system "tasks" {
        name = "copyToPodman";
        description = "Push image of this task to local podman";
        command = "nix run .#tullia.${system}.task.${taskName}.oci.image.copyToPodman";
      })
      (mkCommand system "tasks" {
        name = "copyToRegistry";
        description = "Push image of this task to remote registry";
        command = "nix run .#tullia.${system}.task.${taskName}.oci.image.copyToRegistry";
      })
    ];
}
