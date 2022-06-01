{
  config,
  pkgs,
  lib,
  ...
}: let
  name = "github-ci";
  cfg = config.preset.${name};
in {
  options.preset.${name} = with lib; {
    enable = mkEnableOption "${name} preset";

    repo = mkOption {
      type = types.str;
      description = ''
        Path of the respository (the part after `github.com/`).
      '';
      example = "input-output-hk/tullia";
    };

    sha = mkOption {
      type = types.str;
      example = "841342ce5a67acd93a78e5b1a56e6bbe92db926f";
      description = ''
        The Revision (SHA) of the commit to clone and report status on.
      '';
    };
  };

  config = let
    statusSetup = ''
      function cleanup {
        rm -f "$secret_headers"
      }
      trap cleanup EXIT

      secret_headers="$(mktemp)"

      cat >> "$secret_headers" <<EOF
      Authorization: token $(< "$NOMAD_SECRETS_DIR"/cicero/github/token)
      EOF

      function report {
        echo 'Reporting GitHub commit status: '"$1"

        jq -nc '{
          state: $state,
          context: $action_name,
          description: $description,
          target_url: "\(env.CICERO_WEB_URL)/action/\($action_id)",
        }' \
          --arg state "$1" \
          --arg description "Run $NOMAD_JOB_ID" \
          --arg action_id ${lib.escapeShellArg (config.action.id or "")} \
          --arg action_name ${lib.escapeShellArg (config.action.name or "")} \
        | curl https://github.com/${lib.escapeShellArg cfg.repo} \
          --output /dev/null --fail-with-body \
          --no-progress-meter \
          -H 'Accept: application/vnd.github.v3+json' \
          -H @"$secret_headers" \
          --data-binary @-
      }

      function err {
        report error
      }
      trap err ERR
    '';
    runtimeInputs = with pkgs; [jq curl gitMinimal];
  in
    lib.mkIf cfg.enable {
      # lib.mkBefore is 500, so this will always run before
      commands = lib.mkMerge [
        (lib.mkOrder 400 [
          {
            type = "shell";
            inherit runtimeInputs;
            text = ''
              ${statusSetup}
              report pending

              if [[ ! -d /repo ]]; then
                git clone https://github.com/${lib.escapeShellArg cfg.repo}
                git checkout ${lib.escapeShellArg cfg.sha}
              fi
            '';
          }
        ])

        (lib.mkOrder 1600 [
          {
            type = "shell";
            inherit runtimeInputs;
            text = ''
              ${statusSetup}
              echo task: "$TULLIA_TASK"
              if [[ "$(< /alloc/tullia-status)" = 0 ]]; then
                report success
              else
                report failure
              fi
            '';
          }
        ])
      ];
    };
}
