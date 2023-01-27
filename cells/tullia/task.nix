{
  cell,
  inputs,
}: let
  inherit (cell.library) dependencies;

  cmd = type: text: {
    command = {inherit type text;};
  };
in {
  hello = cmd "ruby" "puts 'Hello World!'";

  goodbye = cmd "elvish" "echo goodbye";

  tidy = {pkgs, ...}:
    cmd "shell" "go mod tidy -v"
    // {dependencies = with pkgs; [go];};

  fail = {
    config ? {},
    lib,
    ...
  }:
    cmd "shell" "exit 10"
    // {
      commands = lib.mkAfter [
        {
          text = ''
            echo These should be 10:
            echo "$TULLIA_STATUS"
            statusVar="TULLIA_STATUS_$TULLIA_TASK"
            echo "''${!statusVar}"
          '';
        }
      ];
    };

  doc = {pkgs, ...}:
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

  lint = {pkgs, ...}:
    cmd "shell" ''
      echo linting go...
      golangci-lint run

      echo linting nix...
      fd -e nix -X alejandra -c
    ''
    // {dependencies = with pkgs; [golangci-lint go gcc fd alejandra];};

  ci = {
    config ? {},
    pkgs,
    ...
  }:
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

  build = {pkgs, ...}:
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

  test-nix-systems = {
    config,
    name,
    pkgs,
    ...
  }: {
    preset.nix.enable = true;

    command.text = ''
      nix-systems || :

      nix show-config

      buildersFile=$(nix show-config --json | jq .builders.value -r)
      cat "''${buildersFile#@}" || :

      whoami
      ls -lah "$HOME" -d || :

      echo "NIX_REMOTE: ''${NIX_REMOTE:-(unset)}"
      ls -lah /nix/var/nix/daemon-socket || :
    '';

    dependencies = with pkgs; [jq];

    nomad = {
      inherit (config.actionRun.facts.trigger.value."tullia/${name}") driver;

      templates = [
        {
          destination = "${config.env.HOME}/readme";
          data = ''
            This file just exists to test our nomad patch
            that should ensure ${config.env.HOME} is owned
            by the task user or nobody.
          '';
        }
      ];
    };
  };
}
