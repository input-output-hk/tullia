{
  cell,
  inputs,
}: let
  pkgs = inputs.nixpkgs;
in {
  tidy = {
    command = "go mod tidy -v";
    dependencies = with pkgs; [go gcc];
  };

  lint = {config ? {}, ...}: {
    command = {
      type = "bash";
      text = ''
        echo linting go...
        golangci-lint run

        echo linting nix...
        fd -e nix -X alejandra -c
      '';
    };
    dependencies = with pkgs; [golangci-lint go gcc fd alejandra];
    env.SHA = config.action.facts.push.value.sha or "no sha";
  };

  hello = {
    command = {
      type = "ruby";
      text = ''
        puts "Hello World!"
        pp ENV
      '';
    };
  };

  bump = {
    command = "ruby bump.rb";
    after = ["tidy"];
    dependencies = with pkgs; [ruby go gcc];
  };

  build = {
    command = "go build -o tullia ./cli";
    after = ["lint"];
    dependencies = with pkgs; [go gcc];
  };

  nix-build = {
    command = "nix build";
    after = ["lint" "bump"];
    dependencies = with pkgs; [go gcc git stdenv];
    memory = 2 * 1024;
  };
}
