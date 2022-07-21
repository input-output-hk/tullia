{
  lib,
  config,
  writers,
  pkgs,
  getImageName,
  ...
}: let
  inherit (lib) mkOption;
  inherit
    (lib.types)
    bool
    package
    submodule
    ;

  flags = {
    v = [
      ''"$alloc:/alloc"''
      ''"$HOME/.netrc:/local/.netrc"''
      ''"$HOME/.docker/config.json:/local/.docker/config.json"''
      ''"$PWD:/repo"''
    ];
    rmi = false;
    rm = true;
    # tty = false;
    # interactive = true;
  };
  imageName = getImageName config.oci.image;
in {
  options.podman = mkOption {
    default = {};
    type = submodule {
      options = {
        run = mkOption {
          type = package;
          description = ''
            Copy the task to local podman and execute it
          '';
          default = writers.shell {
            name = "${config.name}-podman";
            runtimeInputs = [pkgs.coreutils pkgs.podman config.oci.image.copyTo];
            text = ''
              # Podman _can_ work without new(g|u)idmap, but user
              # mapping will be a bit wonky.
              # The problem is that they require suid, so we have to
              # point to the impure location of them.
              suidDir="$(dirname "$(command -v newuidmap)")"
              export PATH="$PATH:$suidDir"
              alloc="''${alloc:-$(mktemp -d -t alloc.XXXXXXXXXX)}"
              function finish {
                rm -rf "$alloc"
              }
              trap finish EXIT
              copy-to containers-storage:${imageName}
              if tty -s; then
                echo "" | exec podman run --tty ${toString (lib.cli.toGNUCommandLine {} flags)} ${imageName}
              else
                echo "" | exec podman run ${toString (lib.cli.toGNUCommandLine {} flags)} ${imageName}
              fi
            '';
          };
        };

        useHostStore = mkOption {
          type = bool;
          default = true;
        };
      };
    };
  };
}
