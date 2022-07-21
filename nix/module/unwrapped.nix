{
  lib,
  writers,
  task,
  config,
  ...
}: let
  inherit (lib) mkOption;
  inherit (lib.types) submodule package;
in {
  options.unwrapped = mkOption {
    default = {};
    type = submodule {
      options = {
        run = mkOption {
          type = package;
          description = ''
            Run the task without any container.
          '';
          default = writers.shell {
            name = "${task.name}-unwrapped";
            runtimeInputs = task.dependencies;
            text = ''
              ${__concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") config.env)}
              exec ${task.computedCommand}/bin/${task.name}
            '';
          };
        };
      };
    };
  };
}
