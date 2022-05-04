{
  cell,
  inputs,
}: {
  ci = inputs.nixpkgs.lib.fileContents ./ci.cue;
}
