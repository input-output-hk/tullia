{
  flake,
  buildGoModule,
}: let
  final = package "sha256-molzDFfwierIXYgAZbQjB3QYiddy9yXDB5kw+aV9ePo=";
  package = vendorSha256:
    buildGoModule rec {
      pname = "tullia";
      version = "2022.04.27.001";
      inherit vendorSha256;

      passthru.invalidHash =
        package "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

      src = flake.inputs.inclusive.lib.inclusive ../. [
        ../go.mod
        ../go.sum
        ../cli
        ../dag
      ];

      postInstall = ''
        mv $out/bin/cli $out/bin/tullia
      '';

      CGO = "0";

      ldflags = [
        "-s"
        "-w"
        "-X main.buildVersion=${version}"
        "-X main.buildCommit=${flake.rev or "dirty"}"
      ];
    };
in
  final
