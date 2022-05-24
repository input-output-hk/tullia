{
  config,
  pkgs,
  lib,
  ...
}: let
  name = "bash";
in {
  options.preset.${name}.enable = lib.mkEnableOption "${name} preset";
  config = lib.mkIf config.preset.${name}.enable {
    dependencies = with pkgs;
      lib.mkDefault [
        coreutils
        bashInteractive
      ];

    env = {
      CURL_CA_BUNDLE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      HOME = lib.mkDefault "/local";
      NIX_SSL_CERT_FILE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      SSL_CERT_FILE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      # PATH = lib.makeBinPath config.dependencies;
      TERM = lib.mkDefault "xterm-256color";
    };

    nsjail = {
      mount."/tmp".options.size = lib.mkDefault 1024;
      bindmount.rw = [
        ''"$root:/"''
        "/dev"
        ''"$alloc:/alloc"''
        ''"$PWD:/repo"''
      ];

      bindmount.ro =
        ["/etc/resolv.conf:/etc/resolv.conf"]
        ++ config.closure.storePaths;
    };
  };
}
