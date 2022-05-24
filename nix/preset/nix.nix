{
  config,
  pkgs,
  lib,
  ...
}: {
  options.preset.nix.enable = lib.mkEnableOption "nix preset";

  config = lib.mkIf config.preset.nix.enable {
    dependencies = with pkgs;
      lib.mkDefault [
        bashInteractive
        cacert
        coreutils-full
        curl
        findutils
        gitMinimal
        gnugrep
        gnutar
        gzip
        iana-etc
        less
        man
        nix
        shadow
        wget
        which
      ];

    env = let
      substituters = {
        "http://alpha.fritz.box:7745/" = "kappa:Ffd0MaBUBrRsMCHsQ6YMmGO+tlh7EiHRFK2YfOTSwag=";
        "https://cache.nixos.org" = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
        "https://hydra.iohk.io" = "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
      };
    in {
      CURL_CA_BUNDLE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      HOME = lib.mkDefault "/local";
      NIX_SSL_CERT_FILE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      SSL_CERT_FILE = lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      # PATH = lib.makeBinPath config.dependencies;
      TERM = lib.mkDefault "xterm-256color";
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
        text = ''
          if [[ -s /registration ]]; then
            if command -v nix-store >/dev/null; then
              nix-store --load-db < /registration
            fi
          fi
        '';
      }
    ]);
  };
}
