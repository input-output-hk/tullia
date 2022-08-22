inputs: system: (let
  pkgs = inputs.nixpkgs.legacyPackages.${system}.extend (
    inputs.nixpkgs.lib.composeManyExtensions [
      inputs.nix-nomad.overlays.default
      (final: prev: {
        lib = prev.lib // {
          # copy-pasted from `nix-nomad/lib/evalNomadJobs.nix` as this is not exposed
          importNomadModule = path: vars: { config, lib, ... }: let
            job = config._module.transformers.Job.fromJSON (lib.importNomadHCL path vars).Job;
          in {
            job.${job.name} = builtins.removeAttrs job ["id" "name"];
          };
        };
      })
    ]
  );
  tullia = inputs.self.defaultPackage.${system};
  inherit (inputs.nix2container.packages.${system}.nix2container) buildImage buildLayer;
  inherit (pkgs.lib) fileContents splitString;
  getClosure = {
    script,
    env,
  }: let
    closure =
      pkgs.closureInfo
      {
        rootPaths = {
          inherit script;
          env = pkgs.writeTextDir "nix-support/env" (builtins.toJSON env);
        };
      };
    content = fileContents "${closure}/store-paths";
  in {
    inherit closure;
    storePaths = splitString "\n" content;
  };
in
  pkgs
  // {
    inherit tullia buildImage buildLayer getClosure;
    inherit (inputs) nix-nomad;
  })
