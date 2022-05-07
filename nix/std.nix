inputs: name: {
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

    runner = runtime:
      pkgs.writeShellApplication {
        name = "run-${taskName}";
        text = ''
          nix build --no-link .#tullia.${system}.wrappedTask.${taskName}.nsjail.run
          ${tullia}/bin/tullia ${lib.escapeShellArg taskName} \
            ${toString (lib.cli.toGNUCommandLine {} {
            task-flake = ".#tullia.${system}.wrappedTask";
            dag-flake = ".#tullia.${system}.dag";
            mode = "passthrough";
            runtime = runtime;
          })}
        '';
      };

    mkAction = runtime: {
      name = runtime;
      description = "run this task in ${runtime}";
      command = ["${runner runtime}/bin/run-${taskName}"];
    };

    nsjailSpec = mkAction "nsjail";
    podmanSpec = mkAction "podman";
  in
    map mkAction ["nsjail" "podman"];
}
