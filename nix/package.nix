{
  flake,
  buildGoModule,
  go-mockery,
}: let
  final = package "sha256-FlT/W+mBpxYJCvjGZyyw5wcUYpsoV9E+JMTeCVVcpD8=";
  package = vendorSha256:
    buildGoModule rec {
      pname = "tullia";
      version = "2022.04.21.001";
      inherit vendorSha256;

      passthru.invalidHash =
        package "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

      src = flake.inputs.inclusive.lib.inclusive ../. [
        ../go.mod
        ../go.sum
        ../cli
        ../dag
      ];

      preBuild = ''
        go generate ./...
      '';

      postInstall = ''
        mv $out/bin/cli $out/bin/tullia
      '';

      ldflags = [
        "-s"
        "-w"
        "-X main.buildVersion=${version}"
        "-X main.buildCommit=${flake.rev or "dirty"}"
      ];
    };
in
  final
