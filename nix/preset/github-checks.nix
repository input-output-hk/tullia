{
  config,
  pkgs,
  lib,
  ...
}: let
  name = "github-checks";
  cfg = config.preset.${name};
in {
  options.preset.${name} = {
    enable = lib.mkEnableOption "${name} preset";

    repo = lib.mkOption {
      type = lib.types.str;
      description = ''
        Path of the repository (the part after `github.com/`).
      '';
      example = "input-output-hk/tullia";
    };
  };

  config = lib.mkIf cfg.enable (let
    createCheckRun = {
      type = "nushell";
      runtimeInputs = with pkgs; [coreutils jq curl];
      text = ''
        let accept = "Accept: application/vnd.github+json"
        let auth = $"Authorization: token $(< $"$NOMAD_SECRETS_DIR/cicero/github/token")"
        let url = 'https://api.github.com/repos/${cfg.repo}/check-runs'
        let createBody = [
          [name $NOMAD_JOB_NAME];
          [details_url $"$CICERO_WEB_URL/run/$NOMAD_JOB_ID"]
          [head_sha "${cfg.sha}"];
          [status in_progress];
          [external_id $NOMAD_JOB_ID];
          [started_at (date now | date format "%+")];
          [output [
            [title "Tullia report"];
            [summary "The summary"];
            [text (open --raw /alloc/log | lines | last 10 | str collect "\n")];
          ]];
        ];

        curl $url -X POST -H $accept -H $auth -d ($createBody | to json)

        let updateBody = $createBody \
          | update status in_progress
        curl $url -X PATCH -H $accept -H $auth -d ($updateBody | to json)

        # gh-check-update --path README.md --annotation_level "warning"
        # Update run

        curl -X PATCH {
          "name": "mighty_readme",
          "status": "completed",
          "conclusion": "success",
          "completed_at": "2018-05-04T01:14:52Z",
          "output": {
            "title": "Mighty Readme report",
            "summary": "There are 0 failures, 2 warnings, and 1 notices.",
            "text": "
            You may have some misspelled words on lines 2 and 4. You also may want to add a section in your README about how to install your app.
            ",
            "annotations": [
              {
                "path": "README.md",
                "annotation_level": "warning",
                "title": "Spell Checker",
                "message": "Check your spelling for 'banaas'.",
                "raw_details": "Do you mean 'bananas' or 'banana'?",
                "start_line": 2,
                "end_line": 2
              },
              {
                "path": "README.md",
                "annotation_level": "warning",
                "title": "Spell Checker",
                "message": "Check your spelling for 'aples'",
                "raw_details": "Do you mean 'apples' or 'Naples'",
                "start_line": 4,
                "end_line": 4
              }
            ],
            "images": [
              {
                "alt": "Super bananas",
                "image_url": "http://example.com/images/42"
              }
            ]
          }
        }
      '';
    };
  in {
  });
}
