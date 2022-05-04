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

  lint = {
    command = ''
      echo linting go...
      golangci-lint run

      echo linting nix...
      fd -e nix -X alejandra -q -c
    '';
    after = ["tidy"];
    dependencies = with pkgs; [golangci-lint go gcc fd alejandra];
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
