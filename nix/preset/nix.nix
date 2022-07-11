{
  config,
  pkgs,
  lib,
  ...
}: {
  options.preset.nix.enable = lib.mkEnableOption "nix preset";

  config = lib.mkIf config.preset.nix.enable {
    nsjail.mount."/tmp".options.size = 1024;
    nsjail.bindmount.ro = lib.mkBefore ["${config.closure.closure}/registration:/registration"];
    oci.contents = let
      substituters = {
        "https://cache.nixos.org" = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
        "https://hydra.iohk.io" = "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
        "https://cache.ci.iog.io" = "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
      };
    in
      lib.mkBefore [
        (
          pkgs.runCommand "etc" {} ''
            mkdir -p $out/etc
            cd $out/etc

            echo > passwd 'nixbld1:x:1000:100:Nix build user 1:/local:/bin/sh'
            echo > shadow 'nixbld1:!:1::::::'
            echo > group  'nixbld:x:100:nixbld1'
            echo > subgid 'nixbld1:1000:100'
            echo > subuid 'nixbld1:1000:100'

            mkdir nix
            cat <<EOF > nix/nix.conf
            experimental-features = ca-derivations flakes nix-command recursive-nix
            log-lines = 1000
            show-trace = true
            sandbox = false
            substituters = ${toString (__attrNames substituters)}
            trusted-public-keys = ${toString (__attrValues substituters)}
            EOF
          ''
        )
      ];

    dependencies = with pkgs; [coreutils gitMinimal nix];

    env.USER = lib.mkDefault "nixbld1";

    commands = lib.mkOrder 300 [
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
    ];
  };
}
