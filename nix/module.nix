{
  lib,
  pkgs,
  config,
  rootDir,
  ociRegistry,
  ...
}: let
  inherit (lib) mkOption mkEnableOption;
  inherit (lib.types) attrsOf submodule attrs str lines listOf enum ints package nullOr bool oneOf either anything strMatching function path;

  sanitizeServiceName = name:
    lib.pipe name [
      (__split "[^[:alnum:]-]+")
      (__filter __isString)
      (__concatStringsSep "-")
    ];

  getImageName = image: "${image.imageName}:${image.imageTag}";

  moduleConfig = config;

  writers = {
    nushell = pkgs.callPackage ./writer/nushell.nix {};
    shell = pkgs.callPackage ./writer/shell.nix {};
    elvish = pkgs.callPackage ./writer/elvish.nix {};
    ruby = pkgs.callPackage ./writer/ruby.nix {};
  };

  computeCommand = task: let
    inherit (task) commands name;

    getText = text:
      if __isPath text
      then __readFile text
      else text;

    makeCommand = command:
      writers.${command.type} {
        inherit name;
        inherit (command) runtimeInputs;
        text = getText command.text;
      };

    mapCommand = command:
      if command.main
      then ''
        TULLIA_STATUS=0
        ${makeCommand command}/bin/${name} || TULLIA_STATUS="$?"
        export TULLIA_STATUS
        export TULLIA_STATUS_${name}="$TULLIA_STATUS"
      ''
      else "${makeCommand command}/bin/${name}";

    commandsWrapped = ''
      ${lib.concatMapStringsSep "\n" mapCommand (
        let
          isMain = {main, ...}: main;
          mainCommands = __filter isMain task.commands;
        in
          if __length mainCommands != 1
          then
            throw ''
              There must be exactly one main command but task "${task.name}" has ${toString (__length mainCommands)}:
              ${lib.concatMapStringsSep "\n" __toJSON (map (lib.filterAttrs (k: v: __elem k ["type" "text"])) mainCommands)}
            ''
          else task.commands
      )}
      exit "$TULLIA_STATUS"
    '';
  in
    writers.shell {
      inherit name;
      text = commandsWrapped;
    };

  taskNomadType = task:
    submodule {
      options = {
        driver = mkOption {
          type = enum ["exec" "nix" "docker" "podman" "java"];
          default = "podman";
        };

        config = mkOption {
          type = attrsOf anything;
          default = {};
        };

        env = mkOption {
          type = attrsOf str;
          default = {};
        };

        resources = mkOption {
          default = {};
          type = submodule {
            options = {
              cpu = mkOption {
                type = ints.positive;
                default = 100;
              };

              memory = mkOption {
                type = ints.positive;
                default = task.memory;
              };

              cores = mkOption {
                type = nullOr ints.positive;
                default = null;
              };
            };
          };
        };

        template = mkOption {
          default = [];
          apply = lib.unique;
          type = listOf (submodule {
            options = let
              duration = strMatching "([[:digit:]]+(y|w|d|h|m|s|ms)){0,7}";
            in {
              destination = mkOption {
                type = str;
              };

              data = mkOption {
                type = lines;
                default = "";
              };

              change_mode = mkOption {
                default = "restart";
                type = enum ["noop" "restart" "signal"];
              };

              change_signal = mkOption {
                default = "";
                type = str;
              };

              perms = mkOption {
                type = strMatching "[[:digit:]]{3,4}";
                default = "644";
              };

              env = mkOption {
                type = bool;
                default = false;
              };

              left_delimiter = mkOption {
                type = str;
                default = "{{";
              };

              right_delimiter = mkOption {
                type = str;
                default = "}}";
              };

              source = mkOption {
                type = str;
                default = "";
              };

              splay = mkOption {
                type = duration;
                default = "5s";
              };
            };
          });
        };

        meta = mkOption {
          type = attrsOf str;
          default = {};
        };

        service = mkOption {
          type = attrsOf anything;
          default = {};
        };
      };

      config = {
        # NOTE: there has to be a better way to get the original value before `apply` ran?
        inherit (task.oci) env;

        config =
          if task.nomad.driver == "podman"
          then {image = lib.mkDefault (task.oci.image // {__toString = _: getImageName task.oci.image;});}
          else throw "Driver '${task.nomad.driver}' not supported yet";
      };
    };

  commandType = task:
    submodule {
      options = {
        type = mkOption {
          type = enum (lib.attrNames writers);
          default = "shell";
          description = ''
            Type of the command
          '';
        };

        runtimeInputs = mkOption {
          type = listOf package;
          default = task.dependencies;
          description = ''
            Dependencies of the command (defaults to task.dependencies)
          '';
        };

        check = mkOption {
          type = bool;
          default = true;
          description = ''
            Check syntax of the command
          '';
        };

        text = mkOption {
          type = either str path;
          description = ''
            Type of the command
          '';
        };

        main = mkOption {
          type = bool;
          default = false;
          internal = true;
          description = ''
            The main task, if this fails all commands in this task will.
          '';
        };
      };
    };

  taskType = submodule ({
    name,
    config,
    options,
    ...
  }: let
    task = config;
    presets = {
      nix = import ./preset/nix.nix;
      bash = import ./preset/bash.nix;
      github-ci = import ./preset/github-ci.nix;
      github-checks = import ./preset/github-checks.nix;
    };
  in {
    imports =
      [
        {
          _module.args = {inherit pkgs writers task getImageName;};
          preset.bash.enable = lib.mkDefault true;
        }
        ./module/bubblewrap.nix
        ./module/nsjail.nix
        ./module/podman.nix
        ./module/docker.nix
        ./module/unwrapped.nix
      ]
      ++ (lib.attrValues presets);

    options = {
      enable = mkEnableOption "the task" // {default = true;};

      after = mkOption {
        type = listOf str;
        default = [];
        description = ''
          Name of Tullia tasks to run after this one.
        '';
      };

      action = mkOption {
        default = {};
        description = ''
          Information provided by Cicero while executing an action.
        '';
        type = submodule {
          options = {
            name = mkOption {
              type = str;
              default = "";
              description = ''
                Name of the Cicero action
              '';
            };

            id = mkOption {
              type = str;
              default = "";
              description = ''
                ID of the Cicero run
              '';
            };

            facts = mkOption {
              default = {};
              description = ''
                Facts that matched the io.
              '';
              type = attrsOf (submodule (
                {name, ...}: {
                  options = {
                    name = mkOption {
                      type = str;
                      default = name;
                      description = ''
                        Name of the fact
                      '';
                    };

                    id = mkOption {
                      type = str;
                      description = ''
                        ID of the fact
                      '';
                    };

                    created_at = mkOption {
                      type = str;
                      description = ''
                        Date and time the fact was created
                      '';
                    };

                    binary_hash = mkOption {
                      type = str;
                      description = ''
                        Binary hash of the fact
                      '';
                    };

                    value = mkOption {
                      type = attrsOf anything;
                      description = ''
                        Value of the fact
                      '';
                    };
                  };
                }
              ));
            };
          };
        };
      };

      command = mkOption {
        type = commandType task;
        default.text = "";
        description = ''
          Command to execute
        '';
      };

      commands = mkOption {
        type = listOf (commandType task);
        description = ''
          Combines the command with any others defined by presets.
        '';
      };

      computedCommand = mkOption {
        type = package;
        readOnly = true;
        internal = true;
        default = computeCommand task;
      };

      closure = mkOption {
        type = attrsOf (either (listOf package) package);
        readOnly = true;
        internal = true;
        default = pkgs.getClosure {
          script = task.computedCommand;
          env = task.env;
        };
      };

      dependencies = mkOption {
        type = listOf package;
        default = [];
        description = ''
          Dependencies used by the command
        '';
      };

      env = mkOption {
        type = attrsOf str;
        default = {
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        };
        description = ''
          Some description of `env`
        '';
      };

      memory = mkOption {
        type = ints.unsigned;
        default = 300;
      };

      name = mkOption {
        # type = strMatching "^[[:alnum:]-]+$";
        type = str;
        default = name;
      };

      run = mkOption {
        type = package;
        default = task.${task.runtime}.run;
        description = ''
          Depending on the `runtime` option, this is a shortcut to `task.<name>.<runtime>.run`.
        '';
      };

      runtime = mkOption {
        type = enum ["nsjail" "bubblewrap" "podman" "docker" "unwrapped"];
        default = "nsjail";
        description = ''
          The runtime determines how tullia executes the task. This directly
          maps to the attribute `task.<name>.<runtime>.run` that is able to be
          executed using `nix run`.
        '';
      };

      workingDir = mkOption {
        type = str;
        default = "/repo";
        description = ''
          The directory that the task will be executed in.
          This defaults to /repo and the source is available there using a
          bindmount when run locally, or cloned when remotely.
        '';
      };

      oci = mkOption {
        default = {};
        type = submodule ({
          config,
          options,
          ...
        }: let
          ociConfig = config;
          ociOptions = options;
        in {
          options = {
            image = mkOption {
              type = package;
              default = pkgs.buildImage {
                inherit (task.oci) name tag maxLayers layers copyToRoot config;
                initializeNixDatabase = true;
              };
            };

            name = mkOption {
              type = str;
              default = "${ociRegistry}/${task.name}";
            };

            tag = mkOption {
              type = nullOr str;
              default = null;
            };

            layers = mkOption {
              type = listOf package;
              default = [];
              # to avoid failure in nix2container's makeNixDatabase
              apply = lib.unique;
              description = ''
                A list of layers built with the buildLayer function: if a store
                path in deps or copyToRoot belongs to one of these layers, this
                store path is skipped. This is pretty useful to isolate store
                paths that are often updated from more stable store paths, to
                speed up build and push time.
              '';
            };

            copyToRoot = mkOption {
              type = listOf package;
              # to avoid failure in nix2container's makeNixDatabase
              apply = lib.unique;
              description = ''
                A list of store paths to include in the layer root. The store
                path prefix /nix/store/hash-path is removed. The store path
                content is then located at the image /.
              '';
            };

            fromImage = mkOption {
              type = str;
              default = "";
              description = ''
                An image that is used as the base image of this image.
              '';
            };

            perms = mkOption {
              default = [];
              type = listOf (submodule {
                options = {
                  path = mkOption {
                    type = str;
                    description = "a store path";
                  };

                  regex = mkOption {
                    type = str;
                    example = ".*";
                  };

                  mode = mkOption {
                    type = str;
                    example = "0664";
                  };
                };
              });
            };

            maxLayers = mkOption {
              type = ints.positive;
              default = 30;
              description = ''
                The maximun number of layer to create. This is based on the
                store path "popularity" as described in
                https://grahamc.com/blog/nix-and-layered-docker-images Note
                this is applied on the image layers and not on layers added
                with the buildImage.layers attribute
              '';
            };

            cmd = mkOption {
              type = listOf str;
              default = [];
              description = ''
                Default arguments to the entrypoint of the
                container. These values act as defaults and may
                be replaced by any specified when creating a
                container. If an Entrypoint value is not
                specified, then the first entry of the Cmd array
                SHOULD be interpreted as the executable to run.
              '';
            };

            entrypoint = mkOption {
              type = listOf str;
              default = [];
              description = ''
                A list of arguments to use as the command to
                execute when the container starts. These values
                act as defaults and may be replaced by an
                entrypoint specified when creating a container.
              '';
            };

            exposedPorts = mkOption {
              type = attrsOf bool;
              default = {};
              description = ''
                A set of ports to expose from a container running
                this image. Its keys can be in the format of:
                port/tcp, port/udp, port with the default
                protocol being tcp if not specified. These values
                act as defaults and are merged with any specified
                when creating a container.
                NOTE: This JSON structure value is unusual
                because it is a direct JSON serialization of the
                Go type map[string]struct{} and is represented in
                JSON as an object mapping its keys to an empty
                object.
                For this config, we filter out all keys with
                false values.
              '';
            };

            env = mkOption {
              type = attrsOf str;
              default = {};
              description = ''
                Entries are in the format of VARNAME=VARVALUE.
                These values act as defaults and are merged with
                any specified when creating a container.
              '';
            };

            volumes = mkOption {
              type = attrsOf anything;
              default = {};
              description = ''
                A set of directories describing where the
                process is likely to write data specific to a
                container instance. NOTE: This JSON structure
                value is unusual because it is a direct JSON
                serialization of the Go type
                map[string]struct{} and is represented in JSON
                as an object mapping its keys to an empty
                object.
              '';
            };

            workingDir = mkOption {
              type = str;
              default = task.workingDir;
              description = ''
                Sets the current working directory of the entrypoint
                process in the container. This value acts as a default
                and may be replaced by a working directory specified when
                creating a container.
              '';
            };

            labels = mkOption {
              type = attrsOf str;
              default = {};
              description = ''
                The field contains arbitrary metadata for the container.
                This property MUST use the annotation rules.
                https://github.com/opencontainers/image-spec/blob/main/annotations.md#rules
              '';
            };

            stopSignal = mkOption {
              type = str;
              default = "";
              description = ''
                The field contains the system call signal that will be
                sent to the container to exit. The signal can be a signal
                name in the format SIGNAME, for instance SIGKILL or
                SIGRTMIN+3.
              '';
            };

            user = mkOption {
              type = str;
              default = "";
              description = ''
                The username or UID which is a platform-specific
                structure that allows specific control over which
                user the process run as. This acts as a default
                value to use when the value is not specified when
                creating a container. For Linux based systems,
                all of the following are valid: user, uid,
                user:group, uid:gid, uid:group, user:gid. If
                group/gid is not specified, the default group and
                supplementary groups of the given user/uid in
                /etc/passwd from the container are applied.
              '';
            };

            config = mkOption {
              default = {};
              type = submodule (imageConfig: {
                options = let
                  toGoStruct = m: lib.mapAttrs (k: v: {}) (lib.filterAttrs (k: v: v) m);
                in {
                  Cmd = mkOption {
                    default = ociConfig.cmd;
                    inherit (ociOptions.cmd) type description;
                  };

                  Entrypoint = mkOption {
                    default = ociConfig.entrypoint;
                    inherit (ociOptions.entrypoint) type description;
                  };

                  ExposedPorts = mkOption {
                    type = attrsOf attrs;
                    default = toGoStruct ociConfig.exposedPorts;
                    inherit (ociOptions.exposedPorts) description;
                  };

                  Env = mkOption {
                    type = listOf str;
                    default = lib.mapAttrsToList (k: v: "${k}=${v}") ociConfig.env;
                    inherit (ociOptions.env) description;
                  };

                  User = mkOption {
                    default = ociConfig.user;
                    inherit (ociOptions.user) type description;
                  };

                  Volumes = mkOption {
                    type = attrsOf attrs;
                    default = toGoStruct ociConfig.volumes;
                    inherit (ociOptions.volumes) description;
                  };

                  WorkingDir = mkOption {
                    default = ociConfig.workingDir;
                    inherit (ociOptions.workingDir) type description;
                  };

                  Labels = mkOption {
                    default = ociConfig.labels;
                    inherit (ociOptions.labels) type description;
                  };

                  StopSignal = mkOption {
                    default = ociConfig.stopSignal;
                    inherit (ociOptions.stopSignal) type description;
                  };
                };
              });
            };
          };

          config = {
            layers = lib.mkDefault (
              lib.optional (rootDir != null) (
                pkgs.buildLayer {
                  copyToRoot = [
                    (pkgs.symlinkJoin {
                      name = "rootDir";
                      paths = [rootDir];
                    })
                  ];
                }
              )
            );

            copyToRoot = lib.mkDefault [
              (pkgs.symlinkJoin {
                name = "root";
                paths = [task.closure.closure] ++ task.dependencies;
              })
            ];

            cmd = lib.mkDefault ["${task.computedCommand}/bin/${task.name}"];
            env = lib.mapAttrs (key: lib.mkDefault) task.env;
            volumes = {
              "/local" = lib.mkDefault true;
              "/tmp" = lib.mkDefault true;
            };
          };
        });
      };

      nomad = mkOption {
        default = {};
        type = taskNomadType config;
      };
    };

    config.commands = [(task.command // {main = true;})];
  });

  jobType = submodule {
    options = {
      namespace = mkOption {
        type = str;
        default = "default";
        description = ''
          Namespace the Nomad job should run in.
        '';
      };

      datacenters = mkOption {
        type = listOf str;
        default = ["dc1"];
        description = ''
          Which datacenters the Nomad job should be scheduled in.
        '';
      };

      type = mkOption {
        type = enum ["batch" "service" "batch" "sysbatch"];
        default = "batch";
        description = ''
          The Nomad job type
        '';
      };

      group = mkOption {
        default = {};
        description = ''
          The Nomad Task Group
        '';
        type = attrsOf (submodule {
          options = {
            reschedule = mkOption {
              type = attrsOf anything;
              default = {};
              description = "Nomad reschedule stanza";
            };

            restart = mkOption {
              type = attrsOf anything;
              default = {};
              description = "Nomad restart stanza";
            };

            task = mkOption {
              default = {};
              type = attrsOf taskType;
              apply = lib.mapAttrs (name: value: value.nomad or value);
              description = "Nomad job stanza";
            };
          };
        });
      };
    };
  };

  actionType = submodule ({
    name,
    config,
    ...
  }: let
    action = config;
  in {
    options = {
      io = mkOption {
        type = either str path;
        apply = v: let
          def = pkgs.runCommand "def.cue" {nativeBuildInputs = [pkgs.cue];} ''
            cue def --simplify > $out \
              ${../lib/prelude.cue} \
              ${../lib/github.cue} \
              ${../lib/slack.cue} \
              ${
              if __isPath v
              then v
              else "- <<< ${lib.escapeShellArg v}"
            }

            substituteInPlace $out \
              --replace '// explicit error (_|_ literal) in source'$'\n' '''
          '';
        in
          lib.fileContents def;
        description = ''
          Path to a CUE file specifying the inputs/outputs of the Cicero action.
        '';
      };

      job = mkOption {
        type = attrsOf jobType;
        default = {};
        description = ''
          The Nomad job generated from the task.
        '';
      };

      task = mkOption {
        type = nullOr str;
        default = null;
        description = ''
          Name of the Tullia task to execute
        '';
      };

      prepare = mkOption {
        type = anything;
        default = let
          mapped = lib.flatten (
            lib.mapAttrsToList (
              jobName: job:
                lib.mapAttrsToList (
                  groupName: group:
                    lib.mapAttrsToList (
                      taskName: task:
                        if task.config ? image
                        then {
                          type = "nix2container";
                          name = getImageName task.config.image;
                          imageDrv = task.config.image.drvPath;
                        }
                        else null
                    )
                    group.task
                )
                job.group
            )
            action.job
          );
        in
          __filter lib.isAttrs mapped;
        description = ''
          Specification of steps Cicero's evaluator must run
          to prepare all that is needed for job execution,
          like pushing the OCI image the job references.
        '';
      };
    };

    config = lib.mkIf (action.task != null) (let
      sname = sanitizeServiceName name;
    in {
      job.${sname}.group.tullia.task.tullia = moduleConfig.wrappedTask.${action.task};
    });
  });
in {
  options = {
    action = mkOption {
      default = {};
      type = attrsOf actionType;
      description = ''
        A Cicero action
      '';
    };

    job = mkOption {
      default = {};
      type = attrsOf jobType;
      description = ''
        A Nomad job
      '';
    };

    task = mkOption {
      default = {};
      type = attrsOf taskType;
      description = ''
        A Tullia task
      '';
    };

    wrappedTask = mkOption {
      default = {};
      type = attrsOf taskType;
      description = ''
        A Tullia task wrapped in the tullia process to also execute its dependencies.
      '';
    };

    dag = mkOption {
      default = {};
      type = attrsOf anything;
      description = ''
        Information for the Tullia execution
      '';
    };
  };

  config = let
    enabledTasks = lib.filterAttrs (name: task: task.enable != null && task.enable != false) config.task;
  in {
    dag = lib.mapAttrs (name: task: task.after) enabledTasks;

    wrappedTask =
      lib.mapAttrs (
        name: task:
        # these must be removed to be assigned their default value that is based on other options
          removeAttrs task ["computedCommand" "closure"]
          // {
            dependencies = [pkgs.tullia];

            command.text = ''
              exec tullia run ${lib.escapeShellArg name}
            '';

            # Discard other commands (e.g. those added by presets).
            # These are meant for the wrapped task, not the wrapper.
            commands = lib.mkForce [(moduleConfig.wrappedTask.${name}.command // {main = true;})];

            env = {
              RUN_SPEC = __toJSON {
                inherit (moduleConfig) dag;
                bin = lib.mapAttrs (n: v: "${v.unwrapped.run}/bin/${n}-unwrapped") enabledTasks;
              };
              MODE = "passthrough";
              RUNTIME = "unwrapped";
            };

            nsjail =
              # `run` must be removed to build a new derivation through the default value
              removeAttrs task.nsjail ["run"]
              // {
                setsid = true;
              };

            # `run` must be removed to build a new derivation through the default value
            podman = removeAttrs task.podman ["run"];

            # these must be removed to configure a new image through their default values
            oci = removeAttrs task.oci ["config" "image" "name" "cmd"];

            nomad =
              task.nomad
              // {
                config = removeAttrs task.nomad.config [
                  # must be removed to build a new image for the wrapper through the default value
                  "image"
                ];

                # propagate max dependencies' resources up to wrapper job
                resources = lib.pipe task.after [
                  (map (name: moduleConfig.wrappedTask.${name}.nomad.resources))
                  (xs: xs ++ [task.nomad.resources])
                  (
                    lib.foldAttrs (
                      a: b:
                        if __elem null [a b]
                        then
                          if a == null
                          then b
                          else a
                        else lib.max a b
                    )
                    null
                  )
                ];
              };
          }
      )
      enabledTasks;
  };
}
