{
  cell,
  inputs,
}: let
  pkgs = inputs.nixpkgs;
  inherit (cell.library) dependencies;
in {
  ci = {
    command.text = "echo CI passed";
    after = ["build" "nix-build"];
  };

  tidy = {
    command.text = "go mod tidy -v";
    inherit dependencies;
  };

  lint = {config ? {}, ...}: {
    command.text = ''
      echo linting go...
      golangci-lint run

      echo linting nix...
      fd -e nix -X alejandra -c
    '';
    inherit dependencies;
    # env.SHA = config.action.facts.push.value.sha or "no sha";
  };

  hello = {
    command.type = "ruby";
    command.text = "puts 'Hello World!'";
  };

  goodbye = {
    command.type = "elvish";
    command.text = "echo goodbye";
  };

  bump = {
    command.type = "ruby";
    command.text = ./bump.rb;
    after = ["tidy" "lint"];
    inherit dependencies;
    preset.nix.enable = true;
  };

  build = {
    command.text = "go build -o tullia ./cli";
    after = ["bump"];
    inherit dependencies;
  };

  nix-build = {config ? {}, ...}: {
    command.text = "nix build";

    inherit dependencies;
    memory = 2 * 1024;

    preset.nix.enable = true;
    preset.github-ci = {
      enable = config ? facts;
      repo = "input-output-hk/tullia";
      sha = config.facts.push.value.sha or null;
    };
  };
}
