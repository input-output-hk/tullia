{
  config,
  pkgs,
  lib,
  ...
}: let
  name = "bash";
in {
  options.preset.${name}.enable = lib.mkEnableOption "${name} preset";
  config = lib.mkIf config.preset.${name}.enable {
    dependencies = with pkgs;
      lib.mkDefault [
        coreutils
        bashInteractive
      ];
    workingDir = lib.mkDefault "/repo";
    # nsjail.env.USER = lib.mkDefault "nixbld1";
    nsjail.mount."/tmp".options.size = lib.mkDefault 1024;
  };
}
