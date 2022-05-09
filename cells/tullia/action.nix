{
  cell,
  inputs,
}: {
  ci = {
    task = "build";
    io = ./ci.cue;
    # github.ci = true;
  };
}
