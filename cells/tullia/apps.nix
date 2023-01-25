{
  cell,
  inputs,
}: let
  inherit (inputs) self std nixpkgs;
  inherit (nixpkgs) lib;

  src = std.incl self [
    (self + /go.mod)
    (self + /go.sum)
    (self + /cli)
  ];

  package = vendorSha256:
    inputs.nixpkgs.buildGoModule rec {
      pname = "tullia";
      version = "2022.05.18.001";
      inherit src vendorSha256;

      meta = with lib; {
        description = "CLI for Cicero tasks and actions";
        homepage = "https://github.com/input-output-hk/tullia";
        maintainers = with maintainers; [manveru dermetfan];
        license = licenses.asl20;
        platforms = platforms.unix;
      };

      passthru.invalidHash =
        package "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

      postInstall = ''
        mv $out/bin/cli $out/bin/tullia
      '';

      CGO = "0";

      ldflags = [
        "-s"
        "-w"
        "-X main.buildVersion=${version}"
        "-X main.buildCommit=${inputs.self.rev or "dirty"}"
      ];
    };
in {
  default = cell.apps.tullia;

  tullia = package "sha256-ui9Rjb/1wYUwIkx+lmjONE003ez3kwsUm9xvlmikEkg=";

  # Ugly wrapper script for `cue fmt` that adheres to the treefmt spec.
  # https://github.com/numtide/treefmt/issues/140
  treefmt-cue = nixpkgs.writeShellApplication {
    name = "treefmt-cue";
    text = ''
      set -euo pipefail

      PATH="$PATH:"${lib.makeBinPath [
        nixpkgs.gitMinimal
        nixpkgs.cue
      ]}

      trap 'rm -rf "$tmp"' EXIT
      tmp="$(mktemp -d)"

      root="$(git rev-parse --show-toplevel)"

      for f in "$@"; do
        fdir="$tmp"/"$(dirname "''${f#"$root"/}")"
        mkdir -p "$fdir"
        cp -a "$f" "$fdir"/
      done
      cp -ar "$root"/.git "$tmp"/

      cd "$tmp"
      cue fmt "''${@#"$root"/}"

      for f in "''${@#"$root"/}"; do
        if [ -n "$(git status --porcelain --untracked-files=no -- "$f")" ]; then
          cp "$f" "$root"/"$f"
        fi
      done
    '';
  };

  # does not compile with rust newer than 1.60.0 (from nixos-22.05)
  mdbook-nix-eval = (__getFlake github:nixos/nixpkgs/0874168639713f547c05947c76124f78441ea46c).legacyPackages.${nixpkgs.system}.rustPlatform.buildRustPackage rec {
    pname = "mdbook-nix-eval";
    version = "1.0.1";

    src = nixpkgs.fetchFromGitHub {
      owner = "jasonrm";
      repo = "mdbook-nix-eval";
      rev = "v${version}";
      sha256 = "sha256-FtrNPiz/CM+wxpKlIi5dEihzjJq/OXcEs+gM7OVx/18=";
    };

    cargoSha256 = "sha256-NSloPyf04APRePSzj/K/ZlJdw/qMyhuY1HAnYhqcTNo=";

    meta = with lib; {
      description = "preprocessor designed to evaluate code blocks containing nix expressions.";
      homepage = "https://github.com/jasonrm/mdbook-nix-eval";
      maintainers = with maintainers; [manveru];
      license = licenses.mpl20;
      platforms = platforms.unix;
    };
  };

  nix-systems = let
    basic = nixpkgs.writeShellApplication {
      name = "nix-systems";

      runtimeInputs = with nixpkgs; [coreutils util-linux jq];

      text = ''
        if [[ $# -eq 0 ]]; then
          stdoutJson=false
        fi

        while getopts :lrIioOh opt; do
          case "$opt" in
            l) remote=false ;;
            r) local=false ;;
            I) stdinJson=false ;&
            i) stdin=true ;;
            o) invert=true ;&
            O) stdoutJson=false ;;
            h)
              >&2 echo 'Without arguments, prints which systems nix can build for on this machine.'
              >&2 echo 'With -l, considers only the system of local machine to be supported.'
              >&2 echo 'With -r, considers only systems of remote builders to be supported.'
              >&2 echo 'With -i, prints whether the systems read from the JSON list on stdin are supported.'
              >&2 echo 'With -I, prints whether the systems read from lines on stdin are supported.'
              >&2 echo 'With -O, prints supported systems line by line.'
              >&2 echo 'With -o, prints unsupported systems line by line.'
              exit
              ;;
            ?)
              >&2 echo 'Unknown flag'
              exit 1
              ;;
          esac
        done
        shift $((OPTIND - 1))

        if [[ -z "''${stdin:-}" ]]; then
          nullInput=--null-input
        fi

        config=$(nix show-config --json)
        builders=$(<<< "$config" jq --raw-output .builders.value)
        if [[ "$builders" = @* ]]; then
          if [[ -r "''${builders#@}" ]]; then
            builders=$(< "''${builders#@}")
          else
            builders='''
          fi
          config=$(
            <<< "$config" \
            jq --arg builders "$builders" '
              .builders.value = (
                $builders |
                split("\n") |
                join(";")
              )
            '
          )
        fi

        jq --raw-{input,output} --slurp ''${nullInput:-} \
          --argjson local "''${local:-true}" \
          --argjson remote "''${remote:-true}" \
          --argjson stdin "''${stdin:-false}" \
          --argjson stdinJson "''${stdinJson:-true}" \
          --argjson invert "''${invert:-false}" \
          --argjson stdoutJson "''${stdoutJson:-true}" \
          --argjson config "$config"  \
          '
            (
              $config |
              [
                if $local
                then .system.value
                else empty
                end
              ] + (
                if $remote
                then
                  .builders.value |
                  split(";") |
                  map(
                    gsub("^\\s+"; "") |
                    split(" ")[1] |
                    split(",")
                  ) |
                  flatten
                else []
                end
              ) |
              unique
            ) as $supported |

            (
              if $stdin
              then
                if $stdinJson
                then fromjson
                else split("\n")
                end |
                map(select(. != "")) |
                with_entries(.key = .value | .value |= IN($supported[]))
              else $supported | with_entries(.key = .value | .value = true)
              end
            ) as $output |

            if $stdoutJson
            then $output
            else
              $output |
              with_entries(select(.value != $invert)) |
              keys | join("\n")
            end
          '
      '';
    };
  in
    basic
    // {
      meta = with lib;
        basic.meta
        // {
          description = "Prints what platforms nix is capable of building for.";
          maintainers = with maintainers; [dermetfan];
          license = licenses.gpl3Plus;
          platforms = platforms.unix;
        };
    };
}
