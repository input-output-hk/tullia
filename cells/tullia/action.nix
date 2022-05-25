{
  cell,
  inputs,
}: let
  pp = cell.library.pp;
in {
  ci = {config, ...}: {
    io = ./ci.cue;
    task = "build";
  };
}
