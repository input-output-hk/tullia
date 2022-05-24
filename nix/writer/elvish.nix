{
  elvish,
  writeTextFile,
  lib,
}: {
  name,
  text,
  runtimeInputs ? [],
  check ? true,
}:
pkgs.writeTextFile {
  inherit name;
  executable = true;
  destination = "/bin/${name}";
  text = ''
    #!${elvish}/bin/elvish

    set paths = [${lib.escapeShellArgs runtimeInputs}]
    if (and ?(test -s /registration) (has-external nix-store)) {
      nix-store --load-db < /registration
    }

    ${text}
  '';

  checkPhase =
    lib.optionalString
    check
    ''
      runHook preCheck
      ${elvish}/bin/elvish -compileonly "$target"
      runHook postCheck
    '';

  meta.mainProgram = name;
}
