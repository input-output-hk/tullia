{
  nushell,
  writeTextFile,
  lib,
}: {
  name,
  text,
  runtimeInputs ? [],
  check ? true,
}:
writeTextFile {
  name = "${name}.nu";
  executable = true;
  destination = "/bin/${name}";
  text = ''
    #!${nushell}/bin/nu

    let-env PATH = ${lib.escapeShellArg (lib.makeBinPath runtimeInputs)}
    if (('/registration' | path type) == 'dir') and (which nix-store | any? true) {
      open --raw /registration | nix-store --load-db
    }

    ${text}
  '';

  checkPhase =
    lib.optionalString
    check
    ''
      runHook preCheck
      HOME="$PWD" ${nushell}/bin/nu -c "(open $target | nu-check -d) or (exit 1)"
      runHook postCheck
    '';

  meta.mainProgram = name;
}
