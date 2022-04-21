{pkgs}: {
  evalActions = modules: let
    actionModule = pkgs.lib.evalModules {
      modules =
        [
          {
            _file = ./lib.nix;
            _module.args = {inherit pkgs;};
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
}
