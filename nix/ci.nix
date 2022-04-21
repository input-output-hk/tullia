{
  pkgs,
  inputs,
  config,
  ...
}: let
  pp = v: __trace (__toJSON v) v;
  name = "tullia/ci/lintAndBuild";
  start = inputs.start.value.${name}.start;
in {
  action.${name} = {
    inputs.start = ''
      "tullia/ci": start: {
        clone_url: string
        sha: string
        statuses_url?: string

        ref?: "refs/heads/\(default_branch)"
        default_branch?: string
      }
    '';

    output.success = {
      ok = true;
      revision = start.sha;
      ref = start.ref or null;
      default_branch = start.default_branch or null;
    };

    job.${name}.group.${name}.task = {
      inherit (config.task) tidy lint;
    };
  };

  task.tidy = {
    dependencies = with pkgs; [go gcc];
    workingDir = "/repo";
    command = ''
      go mod tidy -v
    '';
  };

  task.lint = {
    dependencies = with pkgs; [go golangci-lint gcc];
    after = [config.task.tidy];
    workingDir = "/repo";
    command = ''
      golangci-lint run
    '';
  };

  task.build = {
    workingDir = "/repo";
    after = [config.task.lint];
    command = ''
      nix build
    '';
  };
}
