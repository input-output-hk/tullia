{
  cell,
  inputs,
}: let
  pkgs = inputs.nixpkgs;
  inherit (cell.library) dependencies;

  cmd = type: text: {
    command = {inherit type text;};
  };
in {
  matomo = let
    cfgFile = pkgs.writeText "phpfpm-matomo.conf" ''
      [global]
      daemonize = no
      error_log = /dev/stderr
      systemd_interval = 0

      [matomo]
      catch_workers_output = yes
      group = matomo
      listen = /alloc/matomo.sock
      pm = dynamic
      pm.max_children = 75
      pm.max_requests = 500
      pm.max_spare_servers = 20
      pm.min_spare_servers = 5
      pm.start_servers = 10
      user = matomo
      env[PIWIK_USER_PATH] = /var/lib/matomo
    '';

    iniFile =
      pkgs.runCommand "php.ini" {
        phpOptions = ''
          error_log = 'stderr'
          log_errors = on
        '';
        preferLocalBuild = true;
        passAsFile = ["phpOptions"];
      } ''
        cat ${pkgs.php}/etc/php.ini $phpOptionsPath > $out
      '';

    caddyFile = pkgs.writeTextDir "Caddyfile" ''
      {
        auto_https off
      }

      :7777 {
        root * ${pkgs.matomo}/share
        php_fastcgi unix//alloc/matomo.sock
        file_server

        log {
          level DEBUG
          output stdout
        }
      }
    '';
  in
    cmd "shell" ''
      php-fpm -y ${cfgFile} -c ${iniFile} &
      caddy run -config ${caddyFile}/Caddyfile &
      wait
    ''
    // {
      dependencies = with pkgs; [
        strace
        php
        caddy
        coreutils
      ];
      nsjail.timeLimit = 0;
      memory = 0;
    };

  hello = cmd "ruby" "puts 'Hello World!'";

  goodbye = cmd "elvish" "echo goodbye";

  tidy =
    cmd "shell" "go mod tidy -v"
    // {dependencies = with pkgs; [go];};

  fail = {config ? {}, ...}:
    cmd "shell" "exit 10"
    // {
      commands = pkgs.lib.mkMerge [
        (pkgs.lib.mkOrder 1600 [
          {
            text = ''
              echo this should be 10:
              cat "/alloc/tullia-status-$TULLIA_TASK"
            '';
          }
        ])
      ];
    };

  doc =
    cmd "shell" ''
      echo "$PATH" | tr : "\n"
      nix eval --raw .#doc.fine | sponge doc/src/module.md
      mdbook build ./doc
    ''
    // {
      dependencies = with pkgs; [coreutils moreutils mdbook];
      preset.nix.enable = true;
      memory = 1000;
    };

  lint =
    cmd "shell" ''
      echo linting go...
      golangci-lint run

      echo linting nix...
      fd -e nix -X alejandra -c
    ''
    // {dependencies = with pkgs; [golangci-lint go gcc fd alejandra];};

  ci = {config ? {}, ...}:
    cmd "shell" ''
      echo Fact:
      cat ${pkgs.writeText "fact.json" (builtins.toJSON (config.facts.push or ""))}
      echo CI passed
    ''
    // {
      after = [
        "build"
        "bump"
        "doc"
        "goodbye"
        "hello"
        "lint"
        "nix-build"
        "nix-preset"
        "tidy"
      ];
    };

  bump =
    cmd "ruby" ./bump.rb
    // {
      after = ["tidy" "lint"];
      preset.nix.enable = true;
    };

  build =
    cmd "shell" "go build -o tullia ./cli"
    // {
      after = ["bump"];
      dependencies = with pkgs; [go];
    };

  nix-preset =
    cmd "ruby" ''
      { fetchTarball: 'https://github.com/input-output-hk/tullia/archive/main.tar.gz',
        fetchurl: 'https://github.com/input-output-hk/tullia/archive/main.tar.gz',
        fetchGit: '{ url = "https://github.com/input-output-hk/tullia"; ref = "main"; }',
      }.each do |fun, url|
        puts "try #{fun} #{url}"
        system("nix", "eval", "--json", "--impure", "--expr", <<~NIX)
          builtins.#{fun} #{url}
        NIX
        pp $?
      end
    ''
    // {preset.nix.enable = true;};

  nix-build = {config ? {}, ...}: {
    command.text = "nix build";
    memory = 2 * 1024;
    preset.nix.enable = true;
    preset.github-ci = {
      enable = config ? facts;
      repo = "input-output-hk/tullia";
      sha = config.facts.push.value.sha or null;
    };
  };
}
