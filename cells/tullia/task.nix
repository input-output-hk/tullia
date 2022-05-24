{
  cell,
  inputs,
}: let
  pkgs = inputs.nixpkgs;
  inherit (cell.library) dependencies;
in {
  tidy = {
    command.text = ''
      go mod tidy -v
    '';
    inherit dependencies;
  };

  lint = {config ? {}, ...}: {
    command.text = ''
      echo linting go...
      golangci-lint run

      echo linting nix...
      fd -e nix -X alejandra -c
    '';
    command.check = false;
    inherit dependencies;
    env.SHA = config.action.facts.push.value.sha or "no sha";
  };

  hello = {
    command = {
      type = "ruby";
      text = ''
        pp HOME: ENV["HOME"]
        pp BAR: ENV["BAR"]
        puts "Hello World!"
      '';
    };

    preset.nix.enable = true;
  };

  goodbye = {
    command = {
      type = "elvish";
      text = ''
        echo HOME: $E:HOME
        echo BAR: $E:BAR
        echo "goodbye"
      '';
    };
    after = ["git-clone"];
  };

  bump = {
    command.type = "ruby";
    command.text = ./bump.rb;
    after = ["tidy"];
    inherit dependencies;
  };

  build = {
    command.text = "go build -o tullia ./cli";
    after = ["lint"];
    inherit dependencies;
  };

  nix-build = {config ? {}, ...}: {
    command.text = "nix build";

    inherit dependencies;
    memory = 2 * 1024;

    preset.nix.enable = true;
    preset.github-ci = {
      enable = true;
      repo = "input-output-hk/tullia";
      inherit (config.facts.push.value) sha;
    };
  };

  # github-status-pending = {
  #   command = "github status building";
  #   before = ["*"];
  # };

  # github-status-failure = {
  #   command = "github status failed";
  #   afterFailureOf = ["*"];
  # };

  # github-status-success = {
  #   command = "github status ok";
  #   afterSuccessOf = ["*"];
  # };

  # github-status-success = {
  #   command = "github status failed";
  #   onSuccessOf = ["lint" "bump" "nix-build"];
  # };
}
