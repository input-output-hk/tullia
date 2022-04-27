{
  pkgs,
  devShell,
  inputs,
  config,
  ...
}: let
  name = "tullia/ci/lintAndBuild";
  start = inputs.start.value.${name}.start;
  dependencies = devShell.nativeBuildInputs;
in {
  action.${name} = {
    inputs.start.match = ''
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
      inherit (config.task) tidy lint build bump;
    };
  };

  task.tidy = {
    command = "go mod tidy -v";
    inherit dependencies;
    env.USER = "bar";
  };

  task.lint = {
    command = "golangci-lint run";
    after = [config.task.tidy];
    inherit dependencies;
  };

  task.bump = {
    command = "ruby bump.rb";
    after = [config.task.tidy];
    inherit dependencies;
  };

  task.build = {
    command = "nix build";
    after = [config.task.lint config.task.bump];
    inherit dependencies;
  };
}
