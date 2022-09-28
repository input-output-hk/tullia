{
  cell,
  inputs,
}: {
  dependencies = with inputs.nixpkgs; [
    alejandra
    cell.apps.mdbook-nix-eval
    cell.apps.treefmt-cue
    coreutils
    cue
    fd
    gcc
    gitMinimal
    go
    gocode
    golangci-lint
    gopls
    gotools
    inputs.nix2container.packages.skopeo-nix2container
    mdbook
    mdbook-linkcheck
    mdbook-mermaid
    moreutils
    nsjail
    ruby
    treefmt
  ];
}
