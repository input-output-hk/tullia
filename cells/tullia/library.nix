{
  cell,
  inputs,
}: let
  inherit (builtins) toJSON trace;
  pp = a: pp2 a a;
  pp2 = a: b: trace (toJSON a) b;

  inherit (inputs.nixpkgs.lib) evalModules filterAttrs mapAttrs;
  inherit (inputs.nix2container.packages.nix2container) buildImage;

  pkgs = inputs.nixpkgs // {inherit buildImage;};

  evalActions = modules: let
    actionModule = evalModules {
      modules =
        [
          {
            _file = ./library.nix;
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
      filterAttrs (n: v: n != "task")
      (actionModule.extendModules {
        prefix = [];
        modules = [
          {
            _module.args = {
              inherit name id inputs;
              inherit pkgs;
            };
          }
        ];
      })
      .config
      .action
      .${name};
  in
    mapAttrs (actionName: action: (evalAction actionName)) actionModule.config.action;

  evalTasks = tasks:
    (evalModules {
      modules = [
        {
          _file = ./library.nix;
          _module.args = {
            inherit pkgs;
            name = "";
            id = "";
            inputs = {};
          };
          task = tasks;
        }
        ./module.nix
      ];
    })
    .config;

  dependencies = with pkgs; [
    alejandra
    cell.apps.treefmt-cue
    cue
    fd
    gcc
    go
    gocode
    golangci-lint
    gopls
    gotools
    inputs.nix2container.packages.skopeo-nix2container
    nsjail
    ruby
  ];
  # evaluated = evalTasks tasks;
in {
  inherit pp pp2 evalTasks evalActions dependencies;
  # inherit (evaluated) task dag;
}
