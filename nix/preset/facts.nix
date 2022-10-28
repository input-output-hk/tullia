{
  config,
  lib,
  pkgs,
  ...
}: let
  presetName = "facts";
  cfg = config.preset.${presetName};
in {
  options.preset.${presetName} = with lib; {
    enable = mkEnableOption "${presetName} preset";

    factValueOption = mkOption {
      type = with types;
        coercedTo
        str
        (value: {inherit value;})
        cfg.factValueType;
      inherit (cfg.factValueType) description;
    };

    factValueType = mkOption {
      type = types.optionType;
      internal = true;
      readOnly = true;
      description = ''
        Either a value or a value path in a named fact.
        This can be used to fetch the value at runtime
        so the task's derivation does not depend on it.
      '';
      default = types.submodule ({config, ...}: {
        options = {
          factName = mkOption {
            type = with types; nullOr str;
            default = null;
          };

          valuePath = mkOption {
            type = with types; listOf str;
          };

          value = mkOption {
            type = types.anything;
            description = ''
              The literal value.
              This will cause it to be embedded into the task,
              which means the task has to be rebuilt
              every time the values changes.
            '';
          };

          # Naming this `outPath` allows to coerce the evaluated config to a derivation,
          # which allows to call this by simply interpolating it into a script.
          outPath = mkOption {
            type = types.str;
            internal = true;
            default = getExe (
              pkgs.callPackage ../writer/shell.nix {} {
                name =
                  if config.factName != null
                  then "fact:${config.factName}:${__concatStringsSep "." config.valuePath}"
                  else "value";
                runtimeInputs = [pkgs.jq];
                text =
                  if config.factName != null
                  then ''
                    exec jq --{compact,raw}-output \
                      ${escapeShellArg ("." + concatMapStringsSep "." __toJSON valuePath)} \
                      "$TULLIA_FACTS"/${escapeShellArg factName}.json
                  ''
                  else ''
                    exec echo ${escapeShellArg config.value}
                  '';
              }
            );
          };
        };
      });
    };
  };

  config = let
    facts = pkgs.symlinkJoin {
      name = "facts";
      paths =
        lib.mapAttrsToList
        (k: v: __toFile "${k}.json" (__toJSON v))
        config.actionRun.facts;
    };

    mountFacts = "${facts}:${config.env.TULLIA_FACTS}";
  in
    lib.mkIf cfg.enable {
      env.TULLIA_FACTS = "/alloc/tullia/facts"; # assuming that `$NOMAD_ALLOC_DIR` is `/alloc`

      nomad.templates =
        lib.mapAttrsToList (k: v: {
          # must interpolate NOMAD_ALLOC_DIR to avoid hitting remnants of https://github.com/hashicorp/nomad/issues/9610
          destination = "\${NOMAD_ALLOC_DIR}/${lib.removePrefix "/alloc/" config.env.TULLIA_FACTS}/${k}.json";
          data = __toJSON v;
        })
        config.actionRun.facts;

      nsjail.bindmount.ro = [mountFacts];

      podman.flags.v = [mountFacts];
    };
}
