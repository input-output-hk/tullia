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
    command = ''
      echo SHA is "$SHA"
      echo linting go...
      golangci-lint run

      echo linting nix...
      fd -e nix -X alejandra -q -c
    '';
    after = ["tidy"];
    dependencies = with pkgs; [golangci-lint go gcc fd alejandra];
    env.SHA = config.action.facts.push.value.sha or "no sha";
  };

  bump = {
    command = "ruby bump.rb";
    after = ["lint"];
    dependencies = with pkgs; [ruby];
  };

  build = {
    command = "nix build";
    after = ["bump"];
  };
}
