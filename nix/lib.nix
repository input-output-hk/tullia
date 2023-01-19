inputs: let
  inherit (inputs.nixpkgs.lib) evalModules collect isDerivation nameValuePair getAttrFromPath imap0 optional showAttrPath;
  inherit (builtins) mapAttrs;

  augmentPkgs = import ./augmentPkgs.nix inputs;
in rec {
  evalAction = {
    tasks,
    rootDir ? null,
  }: system: actions: let
    pkgs = augmentPkgs system;
  in
    {
      name,
      id,
      inputs,
      ociRegistry,
      rootDir ? null,
    }: let
      run = {
        action = name;
        run = id;
        facts = inputs;
      };

      inherit
        (evalModules
          {
            specialArgs = {
              inherit (pkgs) lib;
            };

            modules = [
              ./module.nix
              {
                _file = ./lib.nix;
                _module.args = {inherit pkgs rootDir ociRegistry;};
                action = actions;
                task = tasks;
              }
              {
                action =
                  mapAttrs
                  (_: _: {inherit run;})
                  actions;

                task =
                  mapAttrs
                  (_: _: {actionRun = run;})
                  tasks;
              }
            ];
          })
        config
        ;
    in
      config
      // {
        action = __mapAttrs (k: v:
          v
          // {
            # Convert the attrset of jobs (must be only one)
            # to an API JSON job definition.
            job =
              if v.job == {}
              then null # decision action
              else
                pkgs.lib.nix-nomad.transformers.Job.toJSON
                (pkgs.lib.last (__attrValues v.job));
          })
        config.action;
      };

  evalTask = {
    tasks,
    rootDir ? null,
  }: system: task: let
    pkgs = augmentPkgs system;
  in
    (evalModules {
      specialArgs = {
        inherit (pkgs) lib;
      };

      modules = [
        ./module.nix
        {
          _file = ./lib.nix;
          _module.args = {
            inherit pkgs rootDir;
            ociRegistry = "localhost";
          };
          inherit task;
        }
      ];
    })
    .config;

  ciceroFromStd = {
    actions,
    tasks,
    rootDir ? null,
    ...
  }:
    mapAttrs (
      system: actions': (
        mapAttrs (
          actionName: action: let
            inner =
              evalAction {
                tasks = tasks.${system};
                inherit rootDir;
              }
              system {${actionName} = action;};
          in
            further: (inner ({name = actionName;} // further)).action.${actionName}
        )
        actions'
      )
    )
    actions;

  tulliaFromStd = {
    tasks,
    rootDir ? null,
    ...
  }:
    mapAttrs (evalTask {inherit tasks rootDir;}) tasks;

  fromStd = args: {
    # nix run .#tullia.x86_64-linux.task.goodbye.run
    tullia = tulliaFromStd args;
    # nix eval --json .#cicero.x86_64-linux.ci --apply 'a: a { id = 1; inputs = {}; ociRegistry = ""; }'
    cicero = ciceroFromStd args;
  };

  fromSimple = system: {
    tasks ? {},
    actions ? {},
  }: let
    tulliaStd = fromStd {
      tasks.${system} = tasks;
      actions.${system} = actions;
    };
  in {
    tullia = tulliaStd.tullia.${system};
    cicero = tulliaStd.cicero.${system};
  };

  /*
  Like `mapAttrsRecursiveCond` from nixpkgs
  but the condition and mapping functions
  take the attribute path as their first parameter.
  */
  mapAttrsRecursiveCondWithPath = cond: f: let
    recurse = path:
      __mapAttrs (
        name: value: let
          newPath = path ++ [name];
          g =
            if __isAttrs value && cond newPath value
            then recurse
            else f;
        in
          g newPath value
      );
  in
    recurse [];

  /*
  Returns the paths to values that satisfy the given predicate in the given attrset.
  The predicate and recursion predicate functions take path and value as their parameters.
  If the recursion prediate function is null, it defaults to the negated predicate.
  */
  findAttrsRecursiveCond = cond: pred: attrs:
    collect __isList (
      mapAttrsRecursiveCondWithPath
      (
        if cond == null
        then p: v: !pred p v
        else cond
      )
      (
        p: v:
          if pred p v
          then p
          else null
      )
      attrs
    );

  findAttrsRecursive = findAttrsRecursiveCond null;

  # Returns a new attrset from the result of `findAttrsRecursiveCond` using the given naming function.
  findFlattenAttrsRecursiveCond = cond: pred: mkName: attrs:
    __listToAttrs (
      map
      (
        path:
          nameValuePair
          (mkName path)
          (getAttrFromPath path attrs)
      )
      (findAttrsRecursiveCond cond pred attrs)
    );

  /*
  Given an arbitrarily deeply nested attrset of derivations,
  returns an attrset of tasks that build each derivation.
  The `mkName` function receives the path to each attribute
  as its first and only parameter.
  Read about `findAttrsRecursiveCond` for details about the
  `cond` recursion function.
  The returned tasks have extra module options called
  `drvToTask.{attrPath,installable}`, where
  `attrPath` is a read-only list of strings and
  `installable` is an UNDEFINED string that will be passed to `nix build`.
  Make sure to import the returned task in another module that sets `installable`!
  */
  drvToTaskRecursiveCond = cond: mkName: attrs:
    __listToAttrs (
      map
      (
        path:
          nameValuePair
          (mkName path)
          (let
            v = getAttrFromPath path attrs;
          in
            {
              config,
              lib,
              ...
            }: {
              options.drvToTask = with lib; {
                attrPath = mkOption {
                  type = with types; listOf str;
                  default = path;
                  readOnly = true;
                };

                installable = mkOption {
                  type = types.str;
                };
              };

              config = {
                preset.nix.enable = true;

                command.text = ''
                  attr=${lib.escapeShellArg config.drvToTask.installable}
                  echo Building "$attr"…
                  echo -e '\tdrv: '${lib.escapeShellArg (__unsafeDiscardStringContext v.drvPath)}
                  echo -e '\tout: '${lib.escapeShellArg (__unsafeDiscardStringContext v.outPath)}
                  nix build -L "$attr"
                '';
              };
            })
      )
      (findAttrsRecursiveCond cond (_: isDerivation) attrs)
    );

  drvToTaskRecursive = drvToTaskRecursiveCond null;

  /*
  Given a flake output's path as a list of strings and an evaluated flake,
  returns an attrset of tasks for every derivation recursively found.
  The returned tasks have an extra module option called `flakeOutputTask.flakeUrl`
  that defaults to `.` but can be changed.
  Also see `drvToTaskRecursive` for further information about the module
  that is returned for each task.
  */
  flakeOutputTasks = path: flake: let
    mkFlakeFragement = p: showAttrPath (path ++ p);
  in
    __mapAttrs
    (_: task: {
      config,
      lib,
      ...
    }: {
      imports = [task];

      options.flakeOutputTask.flakeUrl = with lib;
        mkOption {
          type = types.str;
          default = ".";
        };

      config.drvToTask.installable = "${config.flakeOutputTask.flakeUrl}#${mkFlakeFragement config.drvToTask.attrPath}";
    })
    (
      drvToTaskRecursive
      mkFlakeFragement
      (getAttrFromPath path flake.outputs)
    );

  /*
  Returns attrset of tullia tasks named with the given prefix
  that run the corresponding task and depend on each other in the order given.
  */
  taskSequence = prefix: tasks: taskNames:
    __listToAttrs (
      imap0 (
        i: taskName:
          nameValuePair
          (prefix + taskName)
          ({...}: {
            imports = [tasks.${taskName}];
            after = optional (i > 0) (
              prefix + __elemAt taskNames (i - 1)
            );
          })
      )
      taskNames
    );
}
