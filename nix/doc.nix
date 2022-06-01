inputs: let
  channelName = "tullia";

  moduleRootPaths = [./.];
  mkModuleUrl = path: "https://github.com/input-output-hk/tullia/blob/main/nix/${path}";

  pkgs = inputs.nixpkgs;
  inherit
    (inputs.nixpkgs.lib)
    attrByPath
    boolToString
    compare
    compareLists
    evalModules
    fold
    hasAttr
    hasPrefix
    mapAttrsToList
    optionalAttrs
    optionAttrSetToDocList
    removePrefix
    removeSuffix
    sort
    splitByAndCompare
    ;

  inherit
    (builtins)
    concatStringsSep
    filter
    isFunction
    isList
    isString
    mapAttrs
    ;

  evaluatedModules = evalModules {
    modules = [
      ./module.nix
      {
        _module.args = {
          pkgs = import ./augmentPkgs.nix inputs "x86_64-linux";
          rootDir = ./.;
          ociRegistry = "localhost";
        };
      }
    ];
  };

  optionsDocs = map cleanUpOption (sort moduleDocCompare
    (filter (opt: opt.visible && !opt.internal && !opt.readOnly)
      (optionAttrSetToDocList evaluatedModules.options)));

  moduleDocCompare = a: b: let
    isEnable = hasPrefix "enable";
    isPackage = hasPrefix "package";
    compareWithPrio = pred: cmp: splitByAndCompare pred compare cmp;
    moduleCmp = compareWithPrio isEnable (compareWithPrio isPackage compare);
  in
    compareLists moduleCmp a.loc b.loc < 0;

  cleanUpOption = opt: let
    applyOnAttr = n: f: optionalAttrs (hasAttr n opt) {${n} = f opt.${n};};
  in
    opt
    // applyOnAttr "declarations" (map mkDeclaration)
    // applyOnAttr "example" substFunction
    // applyOnAttr "default" substFunction
    // applyOnAttr "type" substFunction
    // applyOnAttr "relatedPackages" mkRelatedPackages;

  mkDeclaration = decl: rec {
    path = stripModulePathPrefixes decl;
    url = mkModuleUrl path;
    channelPath = "${channelName}/${path}";
  };

  # We need to strip references to /nix/store/* from the options or
  # else the build will fail.
  stripModulePathPrefixes = let
    prefixes = map (p: "${toString p}/") moduleRootPaths;
  in
    modulePath: fold removePrefix modulePath prefixes;

  # Replace functions by the string <function>
  substFunction = x:
    if builtins.isAttrs x
    then mapAttrs (name: substFunction) x
    else if builtins.isList x
    then map substFunction x
    else if isFunction x
    then "<function>"
    else x;

  # Generate some meta data for a list of packages. This is what
  # `relatedPackages` option of `mkOption` lib/options.nix influences.
  #
  # Each element of `relatedPackages` can be either
  # - a string:   that will be interpreted as an attribute name from `pkgs`,
  # - a list:     that will be interpreted as an attribute path from `pkgs`,
  # - an attrset: that can specify `name`, `path`, `package`, `comment`
  #   (either of `name`, `path` is required, the rest are optional).
  mkRelatedPackages = let
    unpack = p:
      if isString p
      then {
        name = p;
      }
      else if isList p
      then {
        path = p;
      }
      else p;

    repack = args: let
      name = args.name or (concatStringsSep "." args.path);
      path = args.path or [args.name];
      pkg =
        args.package
        or (let
          bail = throw "Invalid package attribute path '${toString path}'";
        in
          attrByPath path bail pkgs);
    in
      {
        attrName = name;
        packageName = pkg.meta.name;
        available = pkg.meta.available;
      }
      // optionalAttrs (pkg.meta ? description) {
        inherit (pkg.meta) description;
      }
      // optionalAttrs (pkg.meta ? longDescription) {
        inherit (pkg.meta) longDescription;
      }
      // optionalAttrs (args ? comment) {inherit (args) comment;};
  in
    map (p: repack (unpack p));

  inspect = v:
    if builtins.isString v
    then "\"${v}\""
    else if builtins.isList v
    then "[${builtins.concatStringsSep ", " (map inspect v)}]"
    else if builtins.isNull v
    then "null"
    else if builtins.isBool v
    then
      if v
      then "true"
      else "false"
    else if builtins.isAttrs v
    then "{${builtins.concatStringsSep "; " (mapAttrsToList (k: v: "${k} = ${inspect v}") v)}}"
    else if builtins.isInt v
    then builtins.toJSON v
    else throw v;

  toMarkdown = entry: let
    hasDescription =
      (entry ? description)
      && entry.description != null; # || throw "${entry.name} has no description";
    mapping =
      {}
      // (optionalAttrs hasDescription {Description = removeSuffix "\n" entry.description;})
      // (optionalAttrs (entry ? example) {Example = "`${inspect entry.example}`";})
      // (optionalAttrs (entry ? default) {Default = "`${inspect entry.default}`";});
  in ''
    ## ${entry.name} : ${entry.type}
    ${builtins.concatStringsSep "\n" (mapAttrsToList (k: v: "${k}: ${v}") mapping)}
  '';

  fine = builtins.unsafeDiscardStringContext (builtins.concatStringsSep "\n" (map toMarkdown optionsDocs));
in {
  inherit fine optionsDocs;
}
