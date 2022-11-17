{
  options,
  config,
  pkgs,
  lib,
  ...
}: let
  name = "github";
  cfg = config.preset.${name};
  writers = lib.genAttrs ["shell" "elvish" "ruby"] (type: pkgs.callPackage ../writer/${type}.nix {});
in {
  options.preset.${name} = with lib; {
    ci = {
      enable = mkEnableOption "preset.github.status and preset.git.clone";
      inherit (options.preset.${name}.status) repository revision;
    };

    status = {
      enable = mkEnableOption "report a GitHub commit status.";

      repository =
        options.preset.facts.factValueOption
        // {
          description = ''
            Path of the repository (the part after `github.com/`).
          '';
          example = "input-output-hk/tullia";
        };

      revision =
        options.preset.facts.factValueOption
        // {
          example = "841342ce5a67acd93a78e5b1a56e6bbe92db926f";
          description = ''
            The SHA of the commit to report a status on.
          '';
        };

      enableActionName = mkEnableOption "prefixing the commit status with the action name";

      lib = mkOption {
        readOnly = true;
        type = with types; lazyAttrsOf unspecified;
        default = {
          report = getExe (writers.shell {
            name = "github-status-report";
            runtimeInputs = with pkgs; [coreutils jq curl];
            text =
              if cfg.status.enable
              then ''
                cfgRevision=$(${lib.escapeShellArg cfg.status.revision})
                cfgRepository=$(${lib.escapeShellArg cfg.status.repository})

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
                  if [[ $ds -gt 0 || "$secs" = 0 ]]; then
                    echo -n ''${ds}s
                  fi

                  echo
                }

                function timer {
                  local cmd="$1"
                  local context="''${2////-}"

                  case "$cmd" in
                    start)
                      mkdir -p "$NOMAD_ALLOC_DIR/tullia/task/$TULLIA_TASK/github-status/$context"
                      date +%s > "$NOMAD_ALLOC_DIR/tullia/task/$TULLIA_TASK/github-status/$context/start-timestamp"
                      ;;
                    stop)
                      local start end
                      start=$(< "$NOMAD_ALLOC_DIR/tullia/task/$TULLIA_TASK/github-status/$context/start-timestamp")
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
                  local context="$1"
                  local state="$2"
                  local description="''${3:-''${state@u}}"

                  echo >&2 -n "Reporting GitHub commit status $state on $cfgRevision for \"$context\""
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
                  | curl "https://api.github.com/repos/$cfgRepository/statuses/$cfgRevision" \
                    --output /dev/null --fail-with-body \
                    --no-progress-meter \
                    -H 'Accept: application/vnd.github.v3+json' \
                    -H @<(echo "Authorization: token $(< "$NOMAD_SECRETS_DIR"/cicero/github/token)") \
                    --data-binary @-
                }

                function reportExitStatus {
                  local context="$1"
                  local exitStatus="''${2:-}"

                  local state
                  if [[ -z "''${exitStatus:-}" ]]; then
                    state=pending
                  elif [[ "$exitStatus" = 0 ]]; then
                    state=success
                  else
                    state=failure
                  fi

                  local description
                  case "$state" in
                    pending)
                      description="Started $(date --rfc-3339=seconds)"
                      timer start "$context"
                      ;;
                    success)
                      description="Took $(timer stop "$context")" ;;
                    failure)
                      description="Exited with $exitStatus after $(timer stop "$context")"
                      ;;
                    error | *)
                      description="Error after $(timer stop "$context")"
                      ;;
                  esac

                  report "$context" "$state" "$description"
                }

                function reportCommand {
                  local context="$1"
                  shift

                  reportExitStatus "$context" '''
                  if "$@"; then
                    reportExitStatus "$context" $?
                  else
                    reportExitStatus "$context" $?
                  fi
                }

                context=${
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

                trap 'report "$context" error' ERR

                while getopts :c:s:d: opt; do
                  case "$opt" in
                    c) context+="$OPTARG" ;;
                    s) state="$OPTARG" ;;
                    d) description="$OPTARG" ;;
                    ?)
                      >&2 echo 'Unknown flag'
                      exit 1
                      ;;
                  esac
                done
                shift $((OPTIND - 1))

                if [[ -n "''${state:-}" ]]; then
                  report "$context" "$state" "''${description:-}"
                  exit
                fi

                if [[ -n "''${description:-}" ]]; then
                  >&2 echo 'error: -d given but makes no sense without -s'
                  exit 1
                fi

                if [[ $# -eq 0 ]]; then
                  reportExitStatus "$context" "''${TULLIA_STATUS:-}"
                else
                  reportCommand "$context" "$@"
                fi
              ''
              else ''
                # ignore all flags
                #shellcheck disable=2034
                while getopts :c:s:d: opt; do :; done
                shift $((OPTIND - 1))

                if [[ $# -gt 0 ]]; then
                  exec "$@"
                fi
              '';
          });

          reportBulk = {
            bulk, # writer args
            each, # writer args
            contextSuffix ? ''" ($elem)"'',
            skippedDescription ? "Skipped",
          }: let
            name = "github-status-report-bulk";

            mkExe = args:
              lib.getExe (
                let
                  type = args.type or "shell";
                in
                  writers.${type} (
                    args
                    // {text = lib.optionalString (type == "shell") "set -o xtrace\n" + args.text;}
                  )
              );

            bulkExe = mkExe ({name = "${name}-bulk";} // bulk);
            eachExe = mkExe ({name = "${name}-each";} // each);
          in
            getExe (writers.shell {
              inherit name;
              runtimeInputs = [pkgs.jq];
              text = ''
                bulk=$(${bulkExe})

                IFS=$'\n'

                for elem in $(<<< "$bulk" jq --raw-output 'with_entries(select(.value != true)) | keys[]'); do
                  ${config.preset.github.status.lib.report} -c ${contextSuffix} -s error -d ${skippedDescription}
                done

                queue=$(<<< "$bulk" jq --raw-output 'with_entries(select(.value)) | keys[]')

                for elem in $queue; do
                  ${config.preset.github.status.lib.report} -c ${contextSuffix} -s pending -d Queued
                done

                for elem in $queue; do
                  ${config.preset.github.status.lib.report} -c ${contextSuffix} -- ${lib.escapeShellArg eachExe} "$elem"
                done
              '';
            });
        };
      };
    };

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
            writers.shell {
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

  config = lib.mkMerge [
    (lib.mkIf cfg.ci.enable {
      preset = {
        ${name}.status = {
          enable = true;
          inherit (cfg.ci) repository revision;
        };

        git.clone = {
          enable = true;
          remote = {
            value = "https://github.com/${cfg.ci.repository.value}";
            outPath = lib.getExe (writers.shell {
              name = "get-git-remote";
              text = ''
                echo -n https://github.com/
                ${lib.escapeShellArg cfg.ci.repository}
              '';
            });
          };
          ref = cfg.ci.revision;
        };
      };
    })

    (lib.mkIf cfg.status.enable {
      commands = let
        reportStatus = {
          type = "shell";
          text = cfg.status.lib.report;
        };
      in
        lib.mkMerge [
          # lib.mkBefore is 500 so this will always run before
          (lib.mkOrder 400 [reportStatus])

          # lib.mkAfter is 1500 so this will always run after
          (lib.mkOrder 1600 [reportStatus])
        ];

      nomad.templates = [
        {
          destination = "\${NOMAD_SECRETS_DIR}/cicero/github/token";
          data = ''{{with secret "kv/data/cicero/github"}}{{.Data.data.token}}{{end}}'';
        }
      ];
    })
  ];
}
