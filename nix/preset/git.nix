{
  options,
  config,
  pkgs,
  lib,
  ...
}: let
  name = "git";
  cfg = config.preset.${name};
in {
  options.preset.${name}.clone = with lib; {
    enable = mkEnableOption "clone a git repo";

    remote =
      options.preset.facts.factValueOption
      // {
        description = "URL of the remote.";
        example = "https://github.com/input-output-hk/tullia";
      };

    ref =
      options.preset.facts.factValueOption
      // {
        description = "The branch name or SHA of the commit to clone.";
        example = "841342ce5a67acd93a78e5b1a56e6bbe92db926f";
      };

    shallow =
      mkEnableOption ''
        shallow clone.
        This requires Git 2.5.0 on client and server
        and the server needs to have set `uploadpack.allowReachableSHA1InWant=true`
        to clone a SHA directly without a branch name.
        Supported by GitHub.
      ''
      // {default = true;};

    enableVault =
      mkEnableOption ''
        Generate a ~/.netrc with a secret pulled from Vault.
        Only works if the remote starts with `https://`.
      ''
      // {default = true;};
  };

  config = lib.mkIf cfg.clone.enable {
    # lib.mkBefore is 500 so this will always run before
    commands = lib.mkOrder 400 [
      {
        type = "shell";
        runtimeInputs = with pkgs; [gitMinimal];
        text =
          ''
            # Exit if the current directory is a git repo because
            # that likely means some dependency task has already cloned.
            if [[ -d .git ]]; then
              exit 0
            fi

            cfgRemote=$(${lib.escapeShellArg cfg.clone.remote})
            cfgRef=$(${lib.escapeShellArg cfg.clone.ref})

            git='git -c advice.detachedHead=false'
          ''
          + (
            if cfg.clone.shallow
            then ''
              $git init --initial-branch=run
              $git remote add origin "$cfgRemote"
              $git fetch --depth 1 origin "$cfgRef"
              $git checkout FETCH_HEAD --
            ''
            else ''
              $git clone "$cfgRemote" .
              $git checkout "$cfgRef" --
            ''
          );
      }
    ];

    nomad.templates = lib.optional (cfg.clone.enableVault && lib.hasPrefix "https://" cfg.clone.remote) {
      destination = "${config.env.HOME}/.netrc";
      data = let
        withoutScheme = lib.removePrefix "https://" cfg.clone.remote; # github.com/owner/repo
        host = __match "([^/]*).*" withoutScheme; # github.com
        service = __match ''(.*)\..*'' host; # github
      in ''
        machine ${host}
        login git
        password {{with secret "kv/data/cicero/${service}"}}{{.Data.data.token}}{{end}}
      '';
    };
  };
}
