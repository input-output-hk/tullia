flakeLib: rec {
  default = tullia;

  tullia = {
    config,
    lib,
    flake-parts-lib,
    ...
  }: {
    options.perSystem = flake-parts-lib.mkPerSystemOption (
      {lib, ...}: {
        options.tullia = with lib; {
          tasks = mkOption {
            type = with types; attrsOf unspecified;
            default = {};
          };

          actions = mkOption {
            type = with types; attrsOf unspecified;
            default = {};
          };
        };
      }
    );

    config = let
      mkSystemOutputs = system: config': let
        simple = flakeLib.fromSimple system config'.tullia;
      in
        simple
        // {
          tullia = {inherit (simple.tullia) task wrappedTask dag;};
        };
    in {
      flake = {
        tullia =
          __mapAttrs
          (system: v: (mkSystemOutputs system v).tullia)
          config.allSystems;

        cicero =
          __mapAttrs
          (system: v: (mkSystemOutputs system v).cicero)
          config.allSystems;
      };

      perInput = system: flake:
        lib.optionalAttrs (flake ? tullia.${system}) {
          tullia = flake.tullia.${system};
        }
        // lib.optionalAttrs (flake ? cicero.${system}) {
          cicero = flake.cicero.${system};
        };
    };
  };
}
