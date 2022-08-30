inputs: let
  inherit (inputs.nixpkgs.lib) evalModules filterAttrs;
  inherit (builtins) mapAttrs;

  augmentPkgs = import ./augmentPkgs.nix inputs;

  evalAction = {
    tasks,
    rootDir ? null,
  }: system: actions: let
    pkgs = augmentPkgs system;
  in
    {
      name,
      id,
      inputs,
      ociRegistry,
      rootDir ? null,
    }: let
      run = {
        action = name;
        run = id;
        facts = inputs;
      };

      inherit
        (evalModules
          {
            specialArgs = {
              inherit (pkgs) lib;
            };

            modules = [
              ./module.nix
              {
                _file = ./lib.nix;
                _module.args = {inherit pkgs rootDir ociRegistry;};
                action = actions;
                task = tasks;
              }
              {
                action =
                  mapAttrs
                  (_: _: {inherit run;})
                  actions;

                task =
                  mapAttrs
                  (_: _: {actionRun = run;})
                  tasks;
              }
            ];
          })
        config
        ;
    in
      config
      // {
        action = __mapAttrs (k: v:
          v
          // {
            # Convert the attrset of jobs (must be only one)
            # to an API JSON job definition.
            job =
              pkgs.lib.nix-nomad.transformers.Job.toJSON
              (pkgs.lib.last (__attrValues v.job));
          })
        config.action;
      };

  evalTask = {
    tasks,
    rootDir ? null,
  }: system: task: let
    pkgs = augmentPkgs system;
  in
    (evalModules {
      specialArgs = {
        inherit (pkgs) lib;
      };

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
  ciceroFromStd = {
    actions,
    tasks,
    rootDir ? null,
    ...
  }:
    mapAttrs (
      system: actions': (
        mapAttrs (
          actionName: action: let
            inner =
              evalAction {
                tasks = tasks.${system};
                inherit rootDir;
              }
              system {${actionName} = action;};
          in
            further: (inner ({name = actionName;} // further)).action.${actionName}
        )
        actions'
      )
    )
    actions;

  tulliaFromStd = {
    tasks,
    rootDir ? null,
    ...
  }:
    mapAttrs (evalTask {inherit tasks rootDir;}) tasks;

  fromStd = args: {
    # nix run .#tullia.x86_64-linux.task.goodbye.run
    tullia = tulliaFromStd args;
    # nix eval --json .#cicero.x86_64-linux.ci --apply 'a: a { id = 1; inputs = {}; ociRegistry = ""; }'
    cicero = ciceroFromStd args;
  };

  fromSimple = system: {
    tasks ? {},
    actions ? {},
  }: let
    tulliaStd = fromStd {
      tasks.${system} = tasks;
      actions.${system} = actions;
    };
  in {
    tullia = tulliaStd.tullia.${system};
    cicero = tulliaStd.cicero.${system};
  };
}
