{
  cell,
  inputs,
}: {
  ci = {
    task = "build";
    io = ./ci.cue;
    # github.ci = true;
  };

  /*
   cd = {
     task = "lint";
     io = ./ci.cue;
   };
   */

  /*
   e2e = {
     task = cell.task.e2e;
     io = inputs.nixpkgs.lib.fileContents ./e2e.cue;
   };
   */
}
