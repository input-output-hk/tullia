{
  config,
  pkgs,
  lib,
  ...
}: let
  presetName = "bash";
in {
  options.preset.${presetName}.enable = lib.mkEnableOption "${presetName} preset";

  config = lib.mkIf config.preset.${presetName}.enable {
    dependencies = with pkgs;
      lib.mkDefault [
        coreutils
        bashInteractive
      ];

    env = {
      CURL_CA_BUNDLE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      HOME = lib.mkDefault "/local/home";
      SSL_CERT_FILE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      # handled by the commandType of the runtimeInputs in modules.nix
      # PATH = lib.makeBinPath config.dependencies;
      TERM = lib.mkDefault "xterm-256color";
      TULLIA_TASK = config.name;
    };

    commands = lib.mkOrder 300 (
      lib.optional (config.runtime == "podman") {
        type = "shell";
        text = ''
          # Set up root user and group.
          echo >> /etc/passwd 'root:x:0:0:System administrator:${config.env.HOME}:/bin/sh'
          echo >> /etc/shadow 'root:!:1::::::'
          echo >> /etc/group  'root:x:0:'
        '';
      }
    );

    nsjail = {
      mount."/tmp".options.size = lib.mkDefault 1024;

      bindmount = {
        rw = lib.mkOrder 300 [
          ''"$root:/"''
          "/dev"
          ''"$alloc:/alloc"''
          ''"$PWD:/repo"''
        ];

        ro = lib.mkOrder 300 (
          ["/etc/resolv.conf:/etc/resolv.conf"]
          ++ config.closure.storePaths
        );
      };
    };
  };
}
