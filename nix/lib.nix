{pkgs, ...} @ args: {
  evalActions = modules: let
    actionModule = pkgs.lib.evalModules {
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
      (actionModule.extendModules {
        prefix = [];
        modules = [{_module.args = {inherit name id inputs;};}];
      })
      .config
      .action
      .${name};
  in
    pkgs.lib.mapAttrs (actionName: action: (evalAction actionName)) actionModule.config.action;

  evalTasks = modules:
    (pkgs.lib.evalModules {
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
