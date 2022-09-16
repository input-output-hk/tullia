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
            mkdir -p $out/etc/nix
            cat <<EOF > $out/etc/nix/nix.conf
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
          # Set up build user and group.
          echo >> /etc/passwd 'nixbld1:x:1000:100:Nix build user 1:${config.env.HOME}:/bin/sh'
          echo >> /etc/shadow 'nixbld1:!:1::::::'
          echo >> /etc/group  'nixbld:x:100:nixbld1'
          echo >> /etc/subgid 'nixbld1:1000:100'
          echo >> /etc/subuid 'nixbld1:1000:100'

          if [[ ! -s /registration ]]; then
            exit 0
          fi

          if command -v nix-store >/dev/null; then
            echo populating nix store...
            nix-store --load-db < /registration
          fi

          # Make sure permissions are open enough.
          # On certain runtimes like containers
          # this may be a volume that is created
          # with the host's umask, thereby possibly
          # having too strict permission bits set.
          # In that case, since the volume mount
          # shadows the container's contents,
          # permissions in the image are never used.
          chmod 1777 /tmp
        '';
      }
    ];
  };
}
