{
  ruby,
  writeTextFile,
  writeText,
  lib,
}: {
  name,
  text,
  runtimeInputs ? [],
  check ? true,
}:
writeTextFile {
  name = "${name}.rb";
  executable = true;
  destination = "/bin/${name}";
  text = let
    file = writeText "import.rb" text;
  in ''
    #!${ruby}/bin/ruby

    ENV["PATH"] = '${lib.makeBinPath runtimeInputs}'

    require "${file}"
  '';

  checkPhase =
    lib.optionalString check
    ''
      runHook preCheck
      ${ruby}/bin/ruby -c "$target"
      runHook postCheck
    '';

  meta.mainProgram = name;
}
