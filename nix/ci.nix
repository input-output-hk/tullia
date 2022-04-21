{
  pkgs,
  inputs,
  config,
  ...
}: let
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
      inherit (config.task) tidy lint build;
    };
  };

  task.tidy = {
    dependencies = with pkgs; [go gcc];
    command = "go mod tidy -v";
  };

  task.lint = {
    dependencies = with pkgs; [go golangci-lint gcc];
    after = [config.task.tidy];
    command = "golangci-lint run";
  };

  task.build = {
    after = [config.task.lint];
    command = "nix build";
  };
}
