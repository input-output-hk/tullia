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
  hello = cmd "ruby" "puts 'Hello World!'";

  goodbye = cmd "elvish" "echo goodbye";

  tidy =
    cmd "shell" "go mod tidy -v"
    // {dependencies = with pkgs; [go];};

  fail = {config ? {}, ...}:
    cmd "shell" "exit 10"
    // {
      commands = pkgs.lib.mkAfter [
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

  nix-build = {config, ...}: {
    command.text = "nix build";
    memory = 2 * 1024;
    preset.nix.enable = true;
    preset.github-ci = {
      enable = config.action.facts or null != null;
      repo = "input-output-hk/tullia";
      sha = config.action.facts.push.value.sha or "";
    };
  };
}
