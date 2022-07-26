inputs: let
  l = inputs.nixpkgs.lib // builtins;
  /*
   Use the Tullia Clade to run your tasks locally as you would in Cicero
   
   Available actions:
     - run
     # - run-in-nsjail
     # - run-in-podman
     # - run-in-x
   */
  tullia = name: {
    inherit name;
    clade = "tullia";
    actions = {
      system,
      flake,
      fragment,
      fragmentRelPath,
    }: let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      inherit (inputs.self.${system}.tullia.apps) tullia;

      /*
       {
         dag = {
           "//cell/organelle/foo" = ["//cell/organelle/bar:run"];
           "//cell/organelle/bar" = [];
         };
       
         bin = {
           foo = "/nix/store/../foo";
           bar = "/nix/store/../bar";
         };
       }
       */
      RunSpecExpr = action:
        l.strings.escapeShellArg ''
          let
            pkgs = (builtins.getFlake "${nixpkgs.sourceInfo.outPath}").legacyPackages.${system};
            inherit (builtins.getFlake "${flake}") __std;
            runSpec' = __listToAttrs ( __filter (i: i != null ) (
              __concatMap (c: __concatMap (o: __concatMap (t:
                if o.clade == "tullia"
                then [{ name = "//" + c.cell + "/" + o.organelle + "/" + t.name; value = {
                  dag = t.deps;
                  # --------------------------------------
                  # this is going to be painstakingly slow
                  bin = __std.actions.${system}.''${c.cell}.''${o.organelle}.''${t.name}.${action}
                  # --------------------------------------
                }; }]
                else (map (a:
                  # --------------------------------------
                  # this is going to be painstakingly slow - even more so
                  # but there can be references to this from any othe task
                  bin = __std.actions.${system}.''${c.cell}.''${o.organelle}.''${t.name}.''${a.name}
                  # --------------------------------------
                ) t.actions )
              ) o.targets ) c.organelles ) __std.init.${system}
            ));
          in {
            dag = __listToAttrs (map (n: {name = n; value = runSpec'.''${n}.dag}) ( __attrNames runSpec'));
            bin = __listToAttrs (map (n: {name = n; value = runSpec'.''${n}.bin}) ( __attrNames runSpec'));
          }
        '';

      runspec = action: ["nix" "eval" "--json" "--impure" "--no-link" "--expr" (RunSpecExpr action)];
    in
      actions
      ++ [
        rec {
          name = "run";
          description = "Run this target with tullia";
          command = "tullia run --run-spec " + (l.concatStringsSep "\t" (runspec name));
        }
        rec {
          name = "run-nsjail";
          description = "Run this target with tullia in nsjail";
          command = "tullia run --run-spec " + (l.concatStringsSep "\t" (runspec name));
        }
        rec {
          name = "run-podman";
          description = "Run this target with tullia in podman";
          command = "tullia run --run-spec " + (l.concatStringsSep "\t" (runspec name));
        }
      ];
  };
in
  tullia
