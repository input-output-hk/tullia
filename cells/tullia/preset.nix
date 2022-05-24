{
  inputs,
  cell,
}: let
  pkgs = inputs.nixpkgs;
in {
  bash = {...}: {
    command.type = "bash";

    env = {
      NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      HOME = "/local";
      TERM = "xterm-256color";
    };

    workingDir = "/repo";
    nsjail.env.USER = "nixbld1";
    nsjail.mount."/tmp".options.size = 1024;

    dependencies = with pkgs; [
      bashInteractive
      bat
      coreutils
      curl
      fd
      findutils
      gitMinimal
      gnugrep
      gnutar
      gzip
      iana-etc
      less
      tree
      which
    ];
  };

  nix = {...}: {
    env = {
      NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      HOME = "/local";
      TERM = "xterm-256color";
      NIX_CONFIG = let
        substituters = {
          "http://alpha.fritz.box:7745/" = "kappa:Ffd0MaBUBrRsMCHsQ6YMmGO+tlh7EiHRFK2YfOTSwag=";
          "https://cache.iog.io" = "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
        };
      in ''
        experimental-features = ca-derivations flakes nix-command
        log-lines = 1000
        show-trace = true
        sandbox = false
      '';
    };

    workingDir = "/repo";
    nsjail.env.USER = "nixbld1";
    nsjail.mount."/tmp".options.size = 1024;

    dependencies = with pkgs; [
      bashInteractive
      coreutils
      curl
      findutils
      gitMinimal
      gnugrep
      gnutar
      gzip
      iana-etc
      less
      nix
      which
    ];
  };
}
