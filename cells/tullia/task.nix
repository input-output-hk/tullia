{
  cell,
  inputs,
}: let
  inherit (cell.library) dependencies;
in {
  tidy = {
    command = "go mod tidy -v";
    inherit dependencies;
  };

  lint = {
    command = ''
      echo linting go...
      golangci-lint run

      echo linting nix...
      fd -e nix -X alejandra -q -c
    '';
    inherit dependencies;
  };

  bump = {
    command = "ruby bump.rb";
    after = ["tidy"];
    inherit dependencies;
  };

  build = {
    command = "nix build";
    after = ["tidy" "lint" "bump"];
    inherit dependencies;
  };
}
