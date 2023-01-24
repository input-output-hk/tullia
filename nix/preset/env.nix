{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.preset.env;
in {
  options.preset.env.enable = lib.mkEnableOption "env preset";

  config = lib.mkIf cfg.enable {
    env = {
      CURL_CA_BUNDLE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      SSL_CERT_FILE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      HOME = lib.mkDefault "/local/home";
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
  };
}
