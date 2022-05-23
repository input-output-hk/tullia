{
  cell,
  inputs,
}: {
  ci = {config, ...}: {
    prestart = ["github-clone" "github-status"];
    prestart-sidecar = ["db"];
    task = "build";
    poststart = ["metrics"];
    poststop = ["report-fact" "github-status"];
    job.ci.group.ci.task.github-status = {
      lifecycle.hook = "poststop";
      driver = "podman";
      config = {
        image = config.task.github-status.oci.name;
      };
    };

    io = ./ci.cue;
  };
}
