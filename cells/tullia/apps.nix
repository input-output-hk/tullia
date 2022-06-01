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
}
