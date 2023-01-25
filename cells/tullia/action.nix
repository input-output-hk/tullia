{
  cell,
  inputs,
}: {
  "tullia/ci" = {
    io = ./ci.cue;
    task = "build";
  };

  "tullia/test-nix-systems" = rec {
    task = "test-nix-systems";
    io = ''
      inputs: trigger: match: "tullia/${task}": driver: *"exec" | "podman"
    '';
  };
}
