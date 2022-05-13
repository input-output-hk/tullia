inputs: let
  inherit (inputs.nixpkgs.lib) evalModules filterAttrs mapAttrs;

  augmentPkgs = system:
    inputs.nixpkgs.legacyPackages.${system}
    // {
      tullia = inputs.self.defaultPackage.${system};
      inherit (inputs.nix2container.packages.${system}.nix2container) buildImage;
    };

  evalAction = {
    actions,
    tasks,
    rootDir ? null,
  }: system: action: let
    pkgs = augmentPkgs system;
  in
    {
      name,
      id,
      inputs,
      ociRegistry,
    }:
      (evalModules
        {
          modules = [
            ./module.nix
            {
              _file = ./lib.nix;
              _module.args = {inherit pkgs rootDir ociRegistry;};
              inherit action;
              task = tasks.${system};
            }
            {
              task =
                builtins.mapAttrs (n: v: {
                  action = {
                    inherit name id;
                    facts = inputs;
                  };
                })
                tasks.${system};
            }
          ];
        })
      .config;

  evalTask = {
    tasks,
    rootDir ? null,
  }: system: task: let
    pkgs = augmentPkgs system;
  in
    (evalModules {
      modules = [
        ./module.nix
        {
          _file = ./lib.nix;
          _module.args = {
            inherit pkgs rootDir;
            ociRegistry = "localhost";
          };
          inherit task;
        }
      ];
    })
    .config;
in rec {
  ciceroFromStd = args:
    builtins.mapAttrs (evalAction args) args.actions;

  tulliaFromStd = args:
    builtins.mapAttrs (evalTask args) args.tasks;

  fromStd = args: {
    tullia = tulliaFromStd {
      inherit (args) tasks;
      rootDir = args.rootDir or null;
    };

    cicero = ciceroFromStd {
      inherit (args) actions tasks;
      rootDir = args.rootDir or null;
    };
  };
}
