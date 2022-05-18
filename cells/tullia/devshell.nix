{
  cell,
  inputs,
}: {
  default = with inputs.nixpkgs;
    mkShell {
      nativeBuildInputs =
        cell.library.dependencies
        ++ [inputs.std.std.cli.default];
    };
}
