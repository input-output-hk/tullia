inputs: system: (let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
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
  pkgs // {inherit tullia buildImage buildLayer getClosure;})
