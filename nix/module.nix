{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption;
  inherit (lib.types) attrsOf submodule attrs str listOf enum ints package nullOr bool oneOf either anything;

  pp2 = a: b: __trace (__toJSON a) b;
  pp = a: __trace (__toJSON a) a;

  getClosure = {
    script,
    env,
  }: let
    closure =
      pkgs.closureInfo
      {
        rootPaths = {
          inherit script;
          env = pkgs.writeTextDir "nix-support/env" (builtins.toJSON env);
        };
      };
    content = lib.fileContents "${closure}/store-paths";
  in {
    inherit closure;
    storePaths = lib.splitString "\n" content;
  };

  # Define presets for tasks.
  # Every preset receives the old task config as an argument and returns
  # attributes to overwrite or add as the result.
  # The result of the preset finally serves as the base of the module
  # evaluation that the user sees and can modify, so ensure proper precedence.
  presets = {
    # You're on your own.
    empty = _: {};

    # A preset with enough to comfortably run Nix builds.
    nix = {config, ...}: {
      dependencies = with pkgs; [
        bashInteractive
        cacert
        coreutils-full
        curl
        findutils
        gitMinimal
        gnugrep
        gnutar
        gzip
        iana-etc
        less
        man
        nix
        shadow
        wget
        which
      ];

      env = {
        CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        HOME = "/local";
        NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        PATH = lib.makeBinPath config.dependencies;
        # TODO: real options for this?
        NIX_CONFIG = ''
          experimental-features = ca-derivations flakes nix-command
          log-lines = 1000
          show-trace = true
          sandbox = false
        '';
      };

      nsjail.env.USER = "nixbld1";
      nsjail.mount."/tmp".options.size = 1024;
    };
  };

  taskNomadType = task: (submodule {
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

      service = mkOption {
        type = attrsOf anything;
        default = {};
      };
    };

    config = {
      # NOTE: there has to be a better way to get the original value before `apply` ran?
      env = lib.listToAttrs (map (e: let
          kv = lib.splitString "=" e;
        in {
          # Since `kv` may have referenced a derivation, we have to clean it
          # because Nix doesn't allow attr keys to have references. This is
          # still safe because the reference lives on in the value.
          name = builtins.unsafeDiscardStringContext (lib.elemAt kv 0);
          value = lib.mkDefault (lib.elemAt kv 1);
        })
        task.oci.config.Env);

      config =
        if task.nomad.driver == "podman"
        then {image = lib.mkDefault "${task.oci.image.imageName}:${task.oci.image.imageTag}";}
        else throw "Driver '${task.nomad.driver}' not supported yet";
    };
  });

  taskType = submodule ({
    name,
    config,
    options,
    ...
  }: let
    task = config;
  in {
    options = {
      name = mkOption {
        type = str;
        default = name;
      };

      preset = mkOption {
        type = enum (lib.attrNames presets);
        default = "nix";
      };

      run = mkOption {
        type = package;
        default = task.${task.runtime}.run;
      };

      dependencies = mkOption {
        type = listOf package;
        default = [];
      };

      command = mkOption {
        type = either str (listOf str);
      };

      after = mkOption {
        type = listOf attrs;
        default = [];
        apply = map (a: a.name);
      };

      env = mkOption {
        type = attrsOf str;
        default = {};
      };

      memory = mkOption {
        type = ints.positive;
        default = 300;
      };

      workingDir = mkOption {
        type = str;
        default = "/local";
      };

      tag = mkOption {
        type = nullOr str;
        default = null;
      };

      runtime = mkOption {
        type = enum ["nsjail" "podman"];
        default = "nsjail";
      };

      oci = mkOption {
        default = {};
        type = submodule {
          options = {
            image = mkOption {
              type = package;
              default = pkgs.buildImage {
                inherit (task.oci) name tag maxLayers contents config;
              };
            };

            innerScript = mkOption {
              type = package;
              default = pkgs.writeShellApplication {
                inherit (task) name;
                text = (
                  if builtins.typeOf task.command == "string"
                  then ''
                    set -x
                    ${task.command}
                  ''
                  else ''
                    set -x
                    ${lib.escapeShellArgs task.command}
                  ''
                );
              };
            };

            name = mkOption {
              type = str;
              default = "docker.infra.aws.iohkdev.io/${task.name}";
            };

            tag = mkOption {
              type = nullOr str;
              default = task.tag;
            };

            layers = mkOption {
              type = listOf package;
              default = [];
              description = ''
                A list of layers built with the buildLayer function: if a store
                path in deps or contents belongs to one of these layers, this
                store path is skipped. This is pretty useful to isolate store
                paths that are often updated from more stable store paths, to
                speed up build and push time.
              '';
            };

            contents = mkOption {
              type = listOf package;
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
              default = 1;
              description = ''
                The maximun number of layer to create. This is based on the
                store path "popularity" as described in
                https://grahamc.com/blog/nix-and-layered-docker-images Note
                this is applied on the image layers and not on layers added
                with the buildImage.layers attribute
              '';
            };

            config = mkOption {
              default = {};
              type = submodule (imageConfig: {
                options = let
                  toGoStruct = m: lib.mapAttrs (k: v: {}) (lib.filterAttrs (k: v: v) m);
                in {
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

                  Cmd = mkOption {
                    default = imageConfig.config.cmd;
                    inherit (imageConfig.options.cmd) type description;
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

                  Entrypoint = mkOption {
                    default = imageConfig.config.entrypoint;
                    inherit (imageConfig.options.entrypoint) type description;
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

                  ExposedPorts = mkOption {
                    type = attrsOf attrs;
                    default = toGoStruct imageConfig.config.exposedPorts;
                    inherit (imageConfig.options.exposedPorts) description;
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

                  Env = mkOption {
                    type = listOf str;
                    default = pkgs.lib.mapAttrsToList (k: v: "${k}=${v}") imageConfig.config.env;
                    inherit (imageConfig.options.env) description;
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

                  User = mkOption {
                    default = imageConfig.config.user;
                    inherit (imageConfig.options.user) type description;
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

                  Volumes = mkOption {
                    type = attrsOf attrs;
                    default = toGoStruct imageConfig.config.volumes;
                    inherit (imageConfig.options.volumes) description;
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

                  WorkingDir = mkOption {
                    default = imageConfig.config.workingDir;
                    inherit (imageConfig.options.workingDir) type description;
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

                  Labels = mkOption {
                    default = imageConfig.config.labels;
                    inherit (imageConfig.options.labels) type description;
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

                  StopSignal = mkOption {
                    default = imageConfig.config.stopSignal;
                    inherit (imageConfig.options.stopSignal) type description;
                  };
                };
              });
            };
          };

          config = let
            inherit
              (getClosure {
                script = task.oci.innerScript;
                env = task.oci.config.Env;
              })
              closure
              ;
          in {
            layers = lib.mkDefault ([closure] ++ task.dependencies);

            contents = lib.mkDefault [
              (pkgs.symlinkJoin {
                name = "root";
                paths = [closure] ++ task.dependencies;
              })
            ];

            config = {
              cmd = lib.mkDefault ["${task.oci.innerScript}/bin/${task.name}"];
              env = lib.mapAttrs (key: value: lib.mkDefault value) task.env;
              volumes."/local" = lib.mkDefault true;
              volumes."/tmp" = lib.mkDefault true;
            };
          };
        };
      };

      nomad = mkOption {
        default = {};
        type = taskNomadType config;
      };

      podman = mkOption {
        default = {};
        type = submodule (podman: {
          options = {
            run = mkOption {
              type = package;
              default = let
                flags = {
                  v = [
                    ''"$alloc:/alloc"''
                    ''"$HOME/.netrc:/local/.netrc"''
                    ''"$HOME/.docker/config.json:/local/.docker/config.json"''
                    ''"$PWD:/repo"''
                  ];
                  rmi = false;
                  rm = true;
                  tty = true;
                  interactive = true;
                };
                imageName = "${config.oci.image.imageName}:${config.oci.image.imageTag}";
              in
                pkgs.writeShellApplication {
                  name = "${config.name}-podman";
                  runtimeInputs = [pkgs.coreutils-full pkgs.podman config.oci.image.copyTo];
                  text = ''
                    set -x
                    # Podman _can_ work without new(g|u)idmap, but user
                    # mapping will be a bit wonky.
                    # The problem is that they require suid, so we have to
                    # point to the impure location of them.
                    suidDir="$(dirname "$(command -v newuidmap)")"
                    export PATH="$PATH:$suidDir"
                    alloc="''${alloc:-$(mktemp -d -t alloc.XXXXXXXXXX)}"
                    function finish {
                      rm -rf "$alloc"
                    }
                    trap finish EXIT
                    copy-to containers-storage:${imageName}
                    podman run ${toString (lib.cli.toGNUCommandLine {} flags)} ${imageName}
                  '';
                };
            };

            useHostStore = mkOption {
              type = bool;
              default = true;
            };
          };
        });
      };

      nsjail = mkOption {
        default = {};
        type = submodule {
          options = {
            run = mkOption {
              type = package;
              default = let
                c = config.nsjail;

                toMountFlag = lib.mapAttrsToList (_: {
                  from,
                  to,
                  type,
                  options,
                }: "${from}:${to}:${type}:${lib.concatStringsSep "," (lib.mapAttrsToList (
                    n: v: let
                      converted =
                        if n == "size"
                        then v * 1024 * 1024 # megabytes to bytes
                        else v;
                    in "${n}=${toString converted}"
                  )
                  options)}");

                flags =
                  (lib.optionalAttrs (c.cgroupV2Mount != null) {
                    cgroupv2_mount = c.cgroupV2Mount;
                  })
                  // {
                    quiet = c.quiet;
                    verbose = c.verbose;
                    time_limit = c.timeLimit;
                    use_cgroupv2 = c.useCgroupV2;
                    disable_clone_newnet = !c.cloneNewnet;
                    rlimit_as = c.rlimit.as;
                    rlimit_core = c.rlimit.core;
                    rlimit_cpu = c.rlimit.cpu;
                    rlimit_fsize = c.rlimit.fsize;
                    rlimit_nofile = c.rlimit.nofile;
                    rlimit_nproc = c.rlimit.nproc;
                    rlimit_stack = c.rlimit.stack;
                    cgroup_cpu_ms_per_sec = c.cgroup.cpuMsPerSec;
                    cgroup_mem_max = c.cgroup.memMax;
                    cgroup_net_cls_classid = c.cgroup.netClsClassid;
                    cgroup_pids_max = c.cgroup.pidsMax;
                    skip_setsid = !c.setsid;
                    cwd = c.cwd;
                    bindmount = c.bindmount.rw;
                    bindmount_ro = c.bindmount.ro;
                    mount = toMountFlag c.mount;
                    env = lib.mapAttrsToList (k: v: lib.escapeShellArg "${k}=${v}") config.env;
                  };
              in
                pkgs.writeShellApplication {
                  name = "${config.name}-nsjail";
                  runtimeInputs = with pkgs; [coreutils-full nsjail];
                  text = ''
                    set -x

                    # TODO: This is tied to systemd... find a way to make it cross-platform.
                    uid="$(id -u)"
                    gid="$(id -g)"
                    export cgroupMount="/sys/fs/cgroup/user.slice/user-$uid.slice/user@$uid.service"
                    export cgroupParent="user@$uid.service"

                    alloc="''${alloc:-$(mktemp -d -t alloc.XXXXXXXXXX)}"
                    root="$(mktemp -d -t root.XXXXXXXXXX)"
                    mkdir -p "$root"/{etc,tmp,local,bin,usr/bin}
                    ln -s ${pkgs.bashInteractive}/bin/sh "$root/bin/sh"
                    ln -s ${pkgs.coreutils-full}/usr/bin/env "$root/usr/bin/env"

                    function finish {
                      chmod u+w -R "$root" 2>/dev/null
                      rm -rf "$alloc" "$root"
                      # rmdir "$cgroup"
                    }
                    trap finish EXIT

                    echo "nixbld:x:$uid:nixbld1" > "$root/etc/group"
                    echo "nixbld1:x:$uid:$gid:nixbld 1:/local:${pkgs.shadow}/bin/nologin" > "$root/etc/passwd"
                    echo "nixbld1:$gid:100" > "$root/etc/subgid"
                    echo "nixbld1:$uid:100" > "$root/etc/subuid"

                    nsjail -Mo ${toString (lib.cli.toGNUCommandLine {} flags)} \
                      --user "$uid" \
                      --group "$gid" \
                      --cgroupv2_mount "$cgroupMount" \
                      --cgroup_cpu_mount "$cgroupMount" \
                      --cgroup_mem_mount "$cgroupMount" \
                      --cgroup_net_cls_mount "$cgroupMount" \
                      --cgroup_pids_mount "$cgroupMount" \
                      --cgroup_cpu_parent "$cgroupParent" \
                      --cgroup_mem_parent "$cgroupParent" \
                      --cgroup_net_cls_parent "$cgroupParent" \
                      --cgroup_pids_parent "$cgroupParent" \
                      -- ${lib.escapeShellArg "${c.innerScript}/bin/${config.name}"}
                  '';
                };
            };

            innerScript = mkOption {
              type = package;
              default =
                pkgs.writeShellScriptBin config.name
                (
                  if builtins.typeOf config.command == "string"
                  then ''
                    [ -s /registration ] && command -v nix-store >/dev/null && nix-store --load-db < /registration
                    ${config.command}
                  ''
                  else lib.escapeShellArgs config.command
                );
            };

            setsid = mkOption {
              type = bool;
              default = true;
              description = ''
                setsid runs a program in a new session.
                Disabling this allows for terminal signal handling in the
                sandboxed process which may be dangerous.
              '';
            };

            quiet = mkOption {
              type = bool;
              default = true;
            };

            verbose = mkOption {
              type = bool;
              default = false;
            };

            timeLimit = mkOption {
              type = ints.unsigned;
              default = 0;
            };

            useCgroupV2 = mkOption {
              type = bool;
              default = true;
            };

            cgroupV2Mount = mkOption {
              type = nullOr str;
              default = null;
            };

            cloneNewnet = mkOption {
              type = bool;
              default = false;
            };

            cwd = mkOption {
              type = str;
              default = "/local";
              description = "change to this directory before starting the script startup";
            };

            bindmount = mkOption {
              default = {};
              type = submodule {
                options = {
                  rw = mkOption {
                    type = listOf str;
                    default = [
                      ''"$root:/"''
                      "/dev"
                      ''"$alloc:/alloc"''
                      ''"$HOME/.docker/config.json:/local/.docker/config.json"''
                      ''"$HOME/.netrc:/local/.netrc"''
                      ''"$PWD:/repo"''
                    ];
                  };

                  ro = mkOption {
                    type = listOf str;
                    default = let
                      inherit
                        (getClosure {
                          script = config.nsjail.innerScript;
                          env = config.env;
                        })
                        closure
                        storePaths
                        ;
                    in
                      ["${closure}/registration:/registration"] ++ storePaths;
                  };
                };
              };
            };

            mount = mkOption {
              default = {};

              type = attrsOf (submodule
                ({name, ...}: {
                  options = {
                    from = mkOption {
                      type = str;
                      default = "none";
                    };

                    to = mkOption {
                      type = str;
                      default = name;
                    };

                    type = mkOption {
                      type = enum ["tmpfs"];
                      default = "tmpfs";
                    };

                    options = mkOption {
                      type = attrsOf anything;
                    };
                  };
                }));
            };

            cgroup = mkOption {
              default = {};
              type = submodule {
                options = {
                  memMax = mkOption {
                    type = ints.unsigned;
                    default = 0;
                    description = "Maximum number of bytes to use in the group. 0 is disabled";
                  };

                  pidsMax = mkOption {
                    type = ints.unsigned;
                    default = 1000;
                    description = "Maximum number of pids in a cgroup. 0 is disabled";
                  };

                  netClsClassid = mkOption {
                    type = ints.unsigned;
                    default = 0;
                    description = "Class identifier of network packets in the group. 0 is disabled";
                  };

                  cpuMsPerSec = mkOption {
                    type = ints.unsigned;
                    default = 0;
                    description = "Number of milliseconds of CPU time per second that the process group can use. 0 is disabled";
                  };
                };
              };
            };

            rlimit = mkOption {
              default = {};
              type = submodule {
                options = {
                  as = mkOption {
                    type = oneOf [(enum ["max" "hard" "def" "soft" "inf"]) ints.unsigned];
                    default = "max";
                    description = "virtual memory size limit in MB";
                  };

                  core = mkOption {
                    type = oneOf [(enum ["max" "hard" "def" "soft" "inf"]) ints.unsigned];
                    default = "max";
                    description = "CPU time in seconds";
                  };

                  cpu = mkOption {
                    type = oneOf [(enum ["max" "hard" "def" "soft" "inf"]) ints.unsigned];
                    default = "max";
                    description = "CPU time in seconds";
                  };

                  fsize = mkOption {
                    type = oneOf [(enum ["max" "hard" "def" "soft" "inf"]) ints.unsigned];
                    default = "max";
                    description = "Maximum file size.";
                  };

                  nofile = mkOption {
                    type = oneOf [(enum ["max" "hard" "def" "soft" "inf"]) ints.unsigned];
                    default = "max";
                    description = "Maximum number of open files.";
                  };

                  nproc = mkOption {
                    type = oneOf [(enum ["max" "hard" "def" "soft" "inf"]) ints.unsigned];
                    default = "soft";
                    description = "Maximum number of processes.";
                  };

                  stack = mkOption {
                    type = oneOf [(enum ["max" "hard" "def" "soft" "inf"]) ints.unsigned];
                    default = "inf";
                    description = "Maximum size of the stack.";
                  };
                };
              };
            };
          };

          config = {
            mount = {
              # "/local".options.size = lib.mkDefault 300;
              # "/tmp".options.size = lib.mkDefault 1000;
            };
          };
        };
      };
    };

    config = let
      preset = presets.${config.preset} {inherit config;};
    in {
      env = lib.mapAttrs (key: value: lib.mkDefault value) (preset.env or {});
      dependencies = preset.dependencies or [];
    };

    /*
     config = let
     preset = presets.${config.preset} {inherit config;};
     in {
     dependencies = lib.mkDefault preset.dependencies;
     env = lib.mapAttrs (key: value: lib.mkDefault value) preset.env;
     };
     */
  });

  jobType = submodule ({name, ...}: {
    options = {
      namespace = mkOption {
        type = str;
        default = "default";
      };

      datacenters = mkOption {
        type = listOf str;
        default = ["dc1"];
      };

      type = mkOption {
        type = enum ["batch" "service" "batch" "sysbatch"];
        default = "batch";
      };

      group = mkOption {
        default = {};
        type = attrsOf (submodule ({...}: {
          options = {
            reschedule = mkOption {
              type = attrsOf anything;
              default = {};
            };

            restart = mkOption {
              type = attrsOf anything;
              default = {};
            };

            task = mkOption {
              default = {};
              # FIXME: somehow the value of this apply ends up being the
              # whole job first and thus doesn't match the type...
              # type = attrsOf taskType;
              type = attrsOf anything;
              apply = lib.mapAttrs (name: value: (value.nomad or value));
            };
          };
        }));
      };
    };
  });

  actionType = submodule ({
    name,
    config,
    ...
  }: {
    options = {
      inputs = mkOption {
        type = attrsOf anything;
      };

      output = mkOption {
        type = attrsOf anything;
      };

      job = mkOption {
        type = attrsOf jobType;
      };

      task = mkOption {
        type = attrsOf taskType;
        default = {};
      };
    };

    config = {
      job.${name}.group.${name}.task = lib.mkIf (config.task != {}) config.task;
    };
  });
in {
  options = {
    action = mkOption {
      default = {};
      type = attrsOf actionType;
    };

    job = mkOption {
      default = {};
      type = attrsOf jobType;
    };

    task = mkOption {
      default = {};
      type = attrsOf taskType;
    };

    dag = mkOption {
      default = {};
      type = attrsOf anything;
    };
  };

  config = {
    dag = lib.mapAttrs (name: task: task.after) config.task;
  };
}
