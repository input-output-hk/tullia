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
      trap 'rm -f "$secret_headers"' EXIT
      secret_headers=$(mktemp)

      cat >> "$secret_headers" <<EOF
      Authorization: token $(< "$NOMAD_SECRETS_DIR"/cicero/github/token)
      EOF

      function report {
        echo >&2 'Reporting GitHub commit status: '"$1"

        local statusVar="TULLIA_STATUS_$TULLIA_TASK"
        local description
        if [[ -z "''${!statusVar:-}" ]]; then
          description="Started $(date --rfc-3339=seconds)"
        else
          description='Exited with '"''${!statusVar}"
        fi

        jq -nc '{
          state: $state,
          context: "\($action_name): \(env.TULLIA_TASK)",
          description: $description,
          target_url: "\(env.CICERO_WEB_URL)/run/\($run_id)",
        }' \
          --arg state "$1" \
          --arg description "$description" \
          --arg run_id "$NOMAD_JOB_ID" \
          --arg action_name ${lib.escapeShellArg config.action.name or ""} \
        | curl ${lib.escapeShellArg "https://api.github.com/repos/${cfg.repo}/statuses/${cfg.sha}"} \
          --output /dev/null --fail-with-body \
          --no-progress-meter \
          -H 'Accept: application/vnd.github.v3+json' \
          -H @"$secret_headers" \
          --data-binary @-
      }

      trap 'report error' ERR
    '';
    runtimeInputs = with pkgs; [coreutils jq curl gitMinimal];
  in
    lib.mkIf cfg.enable {
      commands = lib.mkMerge [
        # lib.mkBefore is 500 so this will always run before
        (lib.mkOrder 400 [
          {
            type = "shell";
            inherit runtimeInputs;
            text = ''
              ${statusSetup}
              report pending

              if [[ -z "$(ls -1Aq)" ]]; then
                git clone https://github.com/${lib.escapeShellArg cfg.repo} .
                git checkout ${lib.escapeShellArg cfg.sha}
              fi
            '';
          }
        ])

        # lib.mkAfter is 1500 so this will always run after
        (lib.mkOrder 1600 [
          {
            type = "shell";
            inherit runtimeInputs;
            text = ''
              ${statusSetup}
              if [[ "$TULLIA_STATUS" = 0 ]]; then
                report success
              else
                report failure
              fi
            '';
          }
        ])
      ];

      nomad.template = [
        {
          destination = "/secrets/cicero/github/token";
          data = ''{{with secret "kv/data/cicero/github"}}{{.Data.data.token}}{{end}}'';
        }
      ];
    };
}
