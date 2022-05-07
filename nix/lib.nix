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
/*
 evalCicero =
   lib.mapAttrs (
     system: action: let
       tulliaLib = tulliaLibFor system;
     in
       {
         name,
         id,
         inputs,
       }: let
         # Rename inputs to facts to make things clearer in the action
         fromCicero = {
           inherit name id;
           facts = inputs;
         };
       in
         (
           tulliaLib.evalActions [
             {
               inherit action;
               task = tasks.${system};
             }
             {
               task = lib.mapAttrs (n: v: {action = fromCicero;}) taskRaw.${system};
             }
           ]
         )
         .${name}
   )
   actions;
 
 evalTasks = modules:
   (evalModules {
     modules =
       [
         {
           _file = ./lib.nix;
           _module.args = args;
         }
         ./module.nix
       ]
       ++ modules;
   })
   .config;
 
 evalActions = modules: let
   actionModule = evalModules {
     modules =
       [
         {
           _file = ./lib.nix;
           _module.args = args;
         }
         ./module.nix
       ]
       ++ modules;
   };
 
   evalAction = name:
     filterAttrs (n: v: n != "task") actionModule.config.action.${name};
 in
   mapAttrs (actionName: action: (evalAction actionName)) actionModule.config.action;
 */

