{
  runtimeShell,
  stdenv,
  lib,
  writeTextFile,
  shellcheck,
}: {
  name,
  text,
  runtimeInputs ? [],
  check ? true,
}:
writeTextFile {
  name = "${name}.sh";
  executable = true;
  destination = "/bin/${name}";
  text = ''
    #!${runtimeShell}
    set -o errexit
    set -o nounset
    set -o pipefail

    export PATH="${lib.makeBinPath runtimeInputs}:$PATH"

    ${text}
  '';

  checkPhase =
    lib.optionalString check
    ''
      runHook preCheck
      ${stdenv.shellDryRun} "$target"
      ${shellcheck}/bin/shellcheck "$target"
      runHook postCheck
    '';

  meta.mainProgram = name;
}
