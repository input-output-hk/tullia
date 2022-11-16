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

  mdbook-nix-eval = nixpkgs.rustPlatform.buildRustPackage rec {
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
        while getopts :fFjh opt; do
          case "$opt" in
            F) invert=1 ;&
            f) filter=1 ;;
            j) jsonInput=1 ;;
            h)
              >&2 echo 'Without arguments, prints which systems nix can build for on this machine.'
              >&2 echo 'With -f, expects a list of systems on stdin and prints only its supported elements.'
              >&2 echo 'With -F, expects a list of systems on stdin and prints only its unsupported elements.'
              >&2 echo 'With -j, expects stdin to be a JSON list.'
              exit
              ;;
            ?)
              >&2 echo 'Unknown flag'
              exit 1
              ;;
          esac
        done
        shift $((OPTIND - 1))

        supported=$(
          {
            config=$(nix show-config --json)

            system=$(<<< "$config" jq --raw-output '.system.value | select(. != null)')
            if [[ -n "$system" ]]; then
              echo "$system"
            fi

            configBuilders=$(<<< "$config" jq --raw-output '.builders.value | select(. != null)')
            <<< "$configBuilders" readarray -d \; -t builders

            for builder in "''${builders[@]}"; do
              systemsComma=$(
                <<< "$builder" \
                column --json --table-columns remote,systems,ssh-id,max-builds,speed-factor,features-supported,features-mandatory,ssh-host \
                | jq --raw-output '.table[].systems | select(. != null)'
              )

              unset builderSystems
              <<< "$systemsComma" readarray -d , -t builderSystems

              for system in "''${builderSystems[@]}"; do
                system="''${system%$'\n'}"
                if [[ -n "$system" ]]; then
                  echo "$system"
                fi
              done
            done
          } | sort --unique
        )

        if [[ -z "''${filter:-}" ]]; then
          echo "$supported"
          exit
        fi

        if [[ -n "''${jsonInput:-}" ]]; then
          input=$(jq --raw-output 'join("\n")')
        else
          while read -r; do
            input+="$REPLY"$'\n'
          done
        fi

        input=$(<<< "$input" sort --unique)

        if [[ -n "''${invert:-}" ]]; then
          while read -r a; do
            while read -r b; do
              if [[ "$a" = "$b" ]]; then
                continue 2
              fi
            done <<< "$supported"
            echo "$a"
          done | sort --unique
        else
          {
            while read -r; do
              echo "$REPLY"
            done
            echo "$supported"
          } | sort | uniq --repeated
        fi <<< "$input"
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
