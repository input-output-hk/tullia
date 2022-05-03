{
  cell,
  inputs,
}: let
  package = vendorSha256:
    inputs.nixpkgs.buildGoModule rec {
      pname = "tullia";
      version = "2022.05.03.001";
      inherit vendorSha256;

      passthru.invalidHash =
        package "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

      src = inputs.std.incl inputs.self [
        (inputs.self + /go.mod)
        (inputs.self + /go.sum)
        (inputs.self + /cli)
        (inputs.self + /dag)
      ];

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
  tullia = package "sha256-12n8Mr0rcPCsbHY0bnpTyXTc2ccVwO/66PiM8EpQxmc=";
}
