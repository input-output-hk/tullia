{
  options,
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

    repo = options.preset.facts.factValueOption // {
      description = ''
        Path of the repository (the part after `github.com/`).
      '';
      example = "input-output-hk/tullia";
    };

    sha = options.preset.facts.factValueOption // {
      example = "841342ce5a67acd93a78e5b1a56e6bbe92db926f";
      description = ''
        The Revision (SHA) of the commit to clone and report status on.
      '';
    };

    clone = {
      enable = mkEnableOption "clone the repo" // {default = true;};

      shallow =
        mkEnableOption ''
          shallow clone.
          This requires Git 2.5.0 on client and server
          and the server needs to have set `uploadpack.allowReachableSHA1InWant=true`.
          Supported by GitHub.
        ''
        // {default = true;};
    };

    status.enableActionName = mkEnableOption "prefixing the commit status with the action name";

    lib = mkOption {
      readOnly = true;
      type = with types; lazyAttrsOf unspecified;
      default = {
        getRevision = factName: default: let
          fact = config.actionRun.facts.${factName} or null;
        in
          fact.value.github_body.pull_request.head.sha
          or fact.value.github_body.head_commit.id
          or fact.value.github_body.after
          or default;

        readRevision = factName: default: {
          outPath = getExe (
            pkgs.callPackage ../writer/shell.nix {} {
              name = "get-${factName}-github-revision";
              runtimeInputs = [pkgs.jq];
              text = ''
                exec jq --{compact,raw}-output \
                  --argjson default ${escapeShellArg (__toJSON default)} \
                  '
                    .value.github_body.pull_request.head.sha //
                    .value.github_body.head_commit.id //
                    .value.github_body.after //
                    $default
                  ' \
                  "$TULLIA_FACTS"/${escapeShellArg factName}.json
              '';
            }
          );
        };
      };
    };
  };

  config = let
    reportStatus = {
      type = "shell";
      runtimeInputs = with pkgs; [coreutils jq curl];
      text = ''
        cfgSha=$(${lib.escapeShellArg cfg.sha})
        cfgRepo=$(${lib.escapeShellArg cfg.repo})

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
              mkdir -p "$NOMAD_ALLOC_DIR/tullia/task/$TULLIA_TASK/github-ci"
              date +%s > "$NOMAD_ALLOC_DIR/tullia/task/$TULLIA_TASK/github-ci/start-timestamp"
              ;;
            stop)
              local start end
              start=$(< "$NOMAD_ALLOC_DIR/tullia/task/$TULLIA_TASK/github-ci/start-timestamp")
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
          lib.pipe config.actionRun.action or null [
            (
              c:
                lib.optionalString
                (cfg.status.enableActionName && c != null)
                "${c}: "
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

          echo >&2 -n "Reporting GitHub commit status $state on $cfgSha for \"$context\""
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
          | curl "https://api.github.com/repos/$cfgRepo/statuses/$cfgSha" \
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
              text =
                reportStatus.text
                + lib.optionalString cfg.clone.enable (
                  ''
                    if [[ -n "$(ls -1Aq)" ]]; then
                      exit 0
                    fi
                    git='git -c advice.detachedHead=false'
                    remote="https://github.com/$cfgRepo"
                  ''
                  + (
                    if cfg.clone.shallow
                    then ''
                      $git init --initial-branch=run
                      $git remote add origin "$remote"
                      $git fetch --depth 1 origin "$cfgSha"
                      $git checkout FETCH_HEAD --
                    ''
                    else ''
                      $git clone $remote .
                      $git checkout "$cfgSha" --
                    ''
                  )
                );
            })
        ])

        # lib.mkAfter is 1500 so this will always run after
        (lib.mkOrder 1600 [reportStatus])
      ];

      nomad.templates = [
        {
          destination = "\${NOMAD_SECRETS_DIR}/cicero/github/token";
          data = ''{{with secret "kv/data/cicero/github"}}{{.Data.data.token}}{{end}}'';
        }
      ];
    };
}
