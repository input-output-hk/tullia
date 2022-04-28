{pkgs, ...} @ args: let
  inherit (pkgs.lib) evalModules filterAttrs mapAttrs;
in {
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

    evalAction = name: {
      id,
      inputs,
      ...
    }:
      filterAttrs (n: v: n != "task")
      (actionModule.extendModules {
        prefix = [];
        modules = [{_module.args = {inherit name id inputs;};}];
      })
      .config
      .action
      .${name};
  in
    mapAttrs (actionName: action: (evalAction actionName)) actionModule.config.action;

  evalTasks = modules:
    (evalModules {
      modules =
        [
          {
            _file = ./lib.nix;
            _module.args =
              args
              // {
                name = "";
                id = "";
                inputs = {};
              };
          }
          ./module.nix
        ]
        ++ modules;
    })
    .config;
}
