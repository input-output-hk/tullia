{
  lib,
  pkgs,
  writers,
  task,
  config,
  getImageName,
  ...
}: let
  inherit (lib) mkOption;
  inherit (lib.types) submodule package;

  imageName = getImageName config.oci.image;

  flags = {
    v = [
      ''"$alloc:/alloc"''
      ''"$HOME/.netrc:/local/.netrc"''
      ''"$HOME/.docker/config.json:/local/.docker/config.json"''
      ''"$PWD:/repo"''
    ];
    rm = true;
    # tty = false;
    # interactive = true;
  };
in {
  options.docker = mkOption {
    default = {};
    type = submodule {
      options = {
        run = mkOption {
          type = package;
          description = ''
            Run the task in Docker.
          '';
          default = writers.shell {
            name = "${task.name}-docker";
            runtimeInputs = [pkgs.coreutils pkgs.docker config.oci.image.copyTo];
            text = ''
              set -x

              alloc="''${alloc:-$(mktemp -d -t alloc.XXXXXXXXXX)}"
              function finish {
                rm -rf "$alloc"
              }
              trap finish EXIT

              command -v copy-to
              copy-to docker-daemon:${imageName}

              if tty -s; then
                exec docker run --tty ${toString (lib.cli.toGNUCommandLine {} flags)} ${imageName}
              else
                exec docker run ${toString (lib.cli.toGNUCommandLine {} flags)} ${imageName}
              fi
            '';
          };
        };
      };
    };
  };
}
