{
  config,
  pkgs,
  lib,
  ...
}: {
  options.preset.nix.enable = lib.mkEnableOption "nix preset";

  config = lib.mkIf config.preset.nix.enable {
    nsjail.mount."/tmp".options.size = lib.mkDefault 1024;
    nsjail.bindmount.ro = lib.mkDefault ["${config.closure.closure}/registration:/registration"];
    oci.contents = lib.mkDefault [
      (
        pkgs.symlinkJoin {
          name = "etc";
          paths = let
            etc = pkgs.runCommand "etc" {} ''
              mkdir -p $out/etc
              echo "nixbld:x:1000:nixbld1" > "$out/etc/group"
              echo "nixbld1:x:1000:$gid:nixbld1:/local:/bin/sh" > "$out/etc/passwd"
              echo "nixbld1:1000:100" > "$out/etc/subgid"
              echo "nixbld1:1000:100" > "$out/etc/subuid"
            '';
          in [etc];
        }
      )
    ];

    dependencies = with pkgs;
      lib.mkDefault [
        coreutils
        gitMinimal
        nix
        # bashInteractive
        # cacert
        # curl
        # findutils
        # gnugrep
        # gnutar
        # gzip
        # iana-etc
        # less
        # shadow
        # wget
        # which
      ];

    env = let
      substituters = {
        "http://alpha.fritz.box:7745/" = "kappa:Ffd0MaBUBrRsMCHsQ6YMmGO+tlh7EiHRFK2YfOTSwag=";
        "https://cache.nixos.org" = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
        "https://hydra.iohk.io" = "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
      };
    in {
      USER = lib.mkDefault "nixbld1";
      # TODO: real options for this?
      NIX_CONFIG = lib.mkDefault ''
        experimental-features = ca-derivations flakes nix-command
        log-lines = 1000
        show-trace = true
        sandbox = false
        substituters = ${toString (builtins.attrNames substituters)}
        trusted-public-keys = ${toString (builtins.attrValues substituters)}
      '';
    };

    commands = lib.mkDefault (lib.mkBefore [
      {
        type = "shell";
        runtimeInputs = [pkgs.nix];
        text = ''
          if [[ -s /registration ]]; then
            if command -v nix-store >/dev/null; then
              echo populating nix store...
              nix-store --load-db < /registration
            fi
          fi
        '';
      }
    ]);
  };
}
