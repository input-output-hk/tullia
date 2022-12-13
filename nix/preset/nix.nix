{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.preset.nix;
in {
  options.preset.nix = with lib; {
    enable = mkEnableOption "nix preset";

    package = mkOption {
      type = types.package;
      default = pkgs.nix;
      description = "The nix package to install.";
    };

    settings = mkOption {
      type = with types; attrsOf anything;
      default = {
        log-lines = 1000;
        show-trace = true;
        extra-substituters = "https://cache.iog.io";
        extra-trusted-public-keys = "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
        extra-experimental-features = "ca-derivations flakes nix-command recursive-nix";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      nsjail.mount."/tmp".options.size = lib.mkDefault 1024;
      nsjail.bindmount.ro = lib.mkBefore ["${config.closure.closure}/registration:/registration"];

      oci.copyToRoot = lib.mkBefore [
        (
          pkgs.runCommand "etc" {} ''
            mkdir -p $out/etc/nix
            cat <<EOF > $out/etc/nix/nix.conf
            sandbox = false
            accept-flake-config = true
            EOF
          ''
        )
      ];

      dependencies = with pkgs; [
        coreutils
        gitMinimal
        cfg.package
        nix-systems
        openssh # for nix remote builds
      ];

      commands = lib.mkOrder 300 [
        {
          type = "shell";
          text = let
            post = ''
              NIX_CONFIG+="''${NIX_CONFIG:+$'\n'}"${lib.escapeShellArg (
                with lib.generators;
                  toKeyValue
                  {mkKeyValue = mkKeyValueDefault {} " = ";}
                  cfg.settings
              )}
              export NIX_CONFIG
            '';
          in ''
            #shellcheck disable=SC2028 disable=SC2016
            echo -n ${lib.escapeShellArg post} > "$TULLIA_COMMAND_POST"
          '';
        }
      ];
    }

    (lib.mkIf (config.runtime == "podman") {
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
          '';
        }
        {
          type = "shell";
          runtimeInputs = [pkgs.coreutils];
          text = ''
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
    })
  ]);
}
