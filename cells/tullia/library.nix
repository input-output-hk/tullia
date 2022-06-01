{
  cell,
  inputs,
}: let
  inherit (builtins) toJSON trace;
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
    cell.apps.mdbook-nix-eval
    cell.apps.treefmt-cue
    coreutils
    cue
    fd
    gcc
    gitMinimal
    go
    gocode
    golangci-lint
    gopls
    gotools
    inputs.nix2container.packages.skopeo-nix2container
    mdbook
    mdbook-linkcheck
    mdbook-mermaid
    moreutils
    nsjail
    ruby
  ];
  # evaluated = evalTasks tasks;
in {
  pp2 = a: b: __trace (__toJSON a) b;
  pp = a: __trace (__toJSON a) a;

  inherit evalTasks evalActions dependencies;
}
