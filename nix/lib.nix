inputs: let
  inherit (inputs.nixpkgs.lib) evalModules filterAttrs mapAttrs fileContents splitString;

  augmentPkgs = system: (let
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    tullia = inputs.self.defaultPackage.${system};
    inherit (inputs.nix2container.packages.${system}.nix2container) buildImage;
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
    pkgs // {inherit tullia buildImage getClosure;});

  evalAction = {
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
              task = tasks;
            }
            {
              task =
                builtins.mapAttrs (n: v: {
                  action = {
                    inherit name id;
                    facts = inputs;
                  };
                })
                tasks;
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
    builtins.mapAttrs (
      system: actions: (
        builtins.mapAttrs (
          actionName: action: let
            inner =
              evalAction {tasks = args.tasks.${system};} system {${actionName} = action;};
          in
            further: (inner ({name = actionName;} // further)).action.${actionName}
        )
        actions
      )
    )
    args.actions;

  tulliaFromStd = {tasks, ...}:
    builtins.mapAttrs (evalTask {inherit tasks;}) tasks;

  fromStd = args: {
    # nix run .#tullia.x86_64-linux.task.goodbye.run
    tullia = tulliaFromStd args;
    # nix eval --json .#cicero.x86_64-linux.ci --apply 'a: a { id = 1; inputs = {}; ociRegistry = ""; }'
    cicero = ciceroFromStd args;
  };
}
