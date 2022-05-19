{
  cell,
  inputs,
}: let
  pkgs = inputs.nixpkgs;
  inherit (cell.library) dependencies;
in {
  tidy = {
    command = {
      type = "bash";
      text = ''
        go mod tidy -v
      '';
    };
    inherit dependencies;
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
    inherit dependencies;
    env.SHA = config.action.facts.push.value.sha or "no sha";
  };

  hello = {
    command = {
      type = "ruby";
      text = ''
        puts "Hello World!"
      '';
    };
  };

  goodbye = {
    command = {
      type = "elvish";
      text = ''
        echo "goodbye"
      '';
    };
  };

  bump = {
    command = {
      type = "ruby";
      text = ./bump.rb;
    };
    after = ["tidy"];
    inherit dependencies;
  };

  build = {
    command = "go build -o tullia ./cli";
    after = ["lint"];
    inherit dependencies;
  };

  nix-build = {
    command = "nix build";
    after = ["lint" "bump"];
    inherit dependencies;
    memory = 2 * 1024;
  };
}
