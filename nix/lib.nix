inputs: let
  inherit (inputs.nixpkgs.lib) evalModules filterAttrs mapAttrs;

  augmentPkgs = nixpkgs: system:
    nixpkgs.legacyPackages.${system}
    // {
      tullia = inputs.self.defaultPackage.${system};
      inherit (inputs.nix2container.packages.${system}.nix2container) buildImage;
    };

  evalAction = {
    actions,
    tasks,
    nixpkgs,
    rootDir,
  }: system: action: let
    pkgs = augmentPkgs nixpkgs system;
  in
    {
      name,
      id,
      inputs,
    }:
      (evalModules
        {
          modules = [
            ./module.nix
            {
              _file = ./lib.nix;
              _module.args = {inherit pkgs rootDir;};
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
    nixpkgs,
    rootDir,
  }: system: task: let
    pkgs = augmentPkgs nixpkgs system;
  in
    (evalModules {
      modules = [
        ./module.nix
        {
          _file = ./lib.nix;
          _module.args = {inherit pkgs rootDir;};
          inherit task;
        }
      ];
    })
    .config;
in {
  ciceroFromStd = args:
    builtins.mapAttrs (evalAction args) args.actions;

  tulliaFromStd = args:
    builtins.mapAttrs (evalTask args) args.tasks;
}
