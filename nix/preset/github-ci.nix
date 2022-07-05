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
    reportStatus = {
      type = "shell";
      runtimeInputs = with pkgs; [coreutils jq curl];
      text = ''
        function duration {
          local secs=$(($2 - $1))

          local dh=$((secs / 3600))
          if [[ $dh -gt 0 ]]; then
            echo -n ''${dh}h
          fi

          local dm=$(((secs / 60) % 60))
          if [[ $dm -gt 0 ]]; then
            echo -n ''${dm}m
          fi

          local ds=$((secs % 60))
          if [[ $ds -gt 0 ]]; then
            echo -n ''${ds}s
          fi

          echo
        }

        function timer {
          case "$1" in
            start)
              mkdir -p "/alloc/tullia/task/$TULLIA_TASK/github-ci"
              date +%s > "/alloc/tullia/task/$TULLIA_TASK/github-ci/start-timestamp"
              ;;
            stop)
              local start end
              start=$(< "/alloc/tullia/task/$TULLIA_TASK/github-ci/start-timestamp")
              end=$(date +%s)
              duration "$start" "$end"
              ;;
            *)
              echo >&2 "Unknown timer command: \"$1\""
              exit 1
              ;;
          esac
        }

        #shellcheck disable=SC2120
        function report {
          local state
          if [[ $# -ge 1 ]]; then
            state="$1"
          elif [[ -z "''${TULLIA_STATUS:-}" ]]; then
            state=pending
          elif [[ "$TULLIA_STATUS" = 0 ]]; then
            state=success
          else
            state=failure
          fi

          local context=${
          lib.pipe config.action.name or null [
            (
              c:
                if c == null
                then ""
                else "${c}: "
            )
            lib.escapeShellArg
            (c: "${c}\"$TULLIA_TASK\"")
          ]
        }

          local description
          case "$state" in
            pending)
              description="Started $(date --rfc-3339=seconds)"
              timer start
              ;;
            success)
              description="Took $(timer stop)" ;;
            failure)
              description="Exited with $TULLIA_STATUS after $(timer stop)"
              ;;
            error | *)
              description="Error after $(timer stop)"
              ;;
          esac

          echo >&2 -n "Reporting GitHub commit status $state on "${lib.escapeShellArg cfg.sha}" for \"$context\""
          if [[ -n "$description" ]]; then
            echo >&2 ": $description"
          else
            echo >&2
          fi

          jq -nc '{
            state: $state,
            context: $context,
            description: $description,
            target_url: "\(env.CICERO_WEB_URL)/run/\(env.NOMAD_JOB_ID)",
          }' \
            --arg state "$state" \
            --arg description "$description" \
            --arg context "$context" \
          | curl ${lib.escapeShellArg "https://api.github.com/repos/${cfg.repo}/statuses/${cfg.sha}"} \
            --output /dev/null --fail-with-body \
            --no-progress-meter \
            -H 'Accept: application/vnd.github.v3+json' \
            -H @<(echo "Authorization: token $(< "$NOMAD_SECRETS_DIR"/cicero/github/token)") \
            --data-binary @-
        }

        trap 'report error' ERR

        report
      '';
    };
  in
    lib.mkIf cfg.enable {
      commands = lib.mkMerge [
        # lib.mkBefore is 500 so this will always run before
        (lib.mkOrder 400 [
          (reportStatus
            // {
              # Merge cloning with reportStatus
              # instead of cloning in a separate command
              # so that reportStatus still traps ERR to report errors.
              runtimeInputs = reportStatus.runtimeInputs ++ [pkgs.gitMinimal];
              text = ''
                ${reportStatus.text}

                if [[ -z "$(ls -1Aq)" ]]; then
                  git clone https://github.com/${lib.escapeShellArg cfg.repo} .
                  git checkout ${lib.escapeShellArg cfg.sha}
                fi
              '';
            })
        ])

        # lib.mkAfter is 1500 so this will always run after
        (lib.mkOrder 1600 [reportStatus])
      ];

      nomad.template = [
        {
          destination = "/secrets/cicero/github/token";
          data = ''{{with secret "kv/data/cicero/github"}}{{.Data.data.token}}{{end}}'';
        }
      ];
    };
}
