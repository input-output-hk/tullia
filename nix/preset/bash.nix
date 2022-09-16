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
      NIX_SSL_CERT_FILE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      SSL_CERT_FILE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      # PATH = lib.makeBinPath config.dependencies;
      TERM = lib.mkDefault "xterm-256color";
      TULLIA_TASK = config.name;
    };

    commands = lib.mkOrder 300 [
      {
        type = "shell";
        text = ''
          # Set up root user and group.
          echo >> /etc/passwd 'root:x:0:0:System administrator:${config.env.HOME}:/bin/sh'
          echo >> /etc/shadow 'root:!:1::::::'
          echo >> /etc/group  'root:x:0:'
        '';
      }
    ];

    nsjail = {
      mount."/tmp".options.size = 1024;
      bindmount.rw = lib.mkOrder 300 [
        ''"$root:/"''
        "/dev"
        ''"$alloc:/alloc"''
        ''"$PWD:/repo"''
      ];

      bindmount.ro = lib.mkOrder 300 (
        ["/etc/resolv.conf:/etc/resolv.conf"]
        ++ config.closure.storePaths
      );
    };
  };
}
