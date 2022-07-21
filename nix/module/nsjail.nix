{
  lib,
  pkgs,
  config,
  writers,
  task,
  ...
}: let
  inherit (lib) mkOption;
  inherit
    (lib.types)
    anything
    attrsOf
    bool
    enum
    ints
    listOf
    oneOf
    package
    str
    submodule
    ;

  c = config.nsjail;

  toMountFlag = lib.mapAttrsToList (_: {
    from,
    to,
    type,
    options,
  }: "${from}:${to}:${type}:${__concatStringsSep "," (lib.mapAttrsToList (
      n: v: let
        converted =
          if n == "size"
          then v * 1024 * 1024 # megabytes to bytes
          else v;
      in "${n}=${toString converted}"
    )
    options)}");

  flags = {
    quiet = c.quiet;
    verbose = c.verbose;
    time_limit = c.timeLimit;
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
    env = lib.mapAttrsToList (k: v: lib.escapeShellArg "${k}=${v}") (config.env);
  };
in {
  options.nsjail = mkOption {
    default = {};
    type = submodule {
      options = {
        run = mkOption {
          type = package;
          description = ''
            Execute the task in a nsjail sandbox
          '';
          default = writers.shell {
            name = "${config.name}-nsjail";
            runtimeInputs = with pkgs; [coreutils nsjail];
            text = ''
              # TODO: This is tied to systemd... find a way to make it cross-platform.
              uid="''${UID:-$(id -u)}"
              gid="''${GID:-$(id -g)}"

              cgroupV2Mount="/sys/fs/cgroup/user.slice/user-$uid.slice/user@$uid.service"
              if [ ! -d "$cgroupV2Mount" ]; then
                unset cgroupV2Mount
              fi

              alloc="''${alloc:-$(mktemp -d -t alloc.XXXXXXXXXX)}"
              root="$(mktemp -d -t root.XXXXXXXXXX)"
              mkdir -p "$root"/{etc,tmp,local,bin,usr/bin}
              ln -s ${pkgs.bashInteractive}/bin/sh "$root/bin/sh"
              ln -s ${pkgs.coreutils}/usr/bin/env "$root/usr/bin/env"

              function finish {
                status="$?"
                chmod u+w -R "$root" 2>/dev/null
                rm -rf "$alloc" "$root"
                exit "$status"
              }
              trap finish EXIT

              echo "nixbld:x:$uid:nixbld1" > "$root/etc/group"
              echo "nixbld1:x:$uid:$gid:nixbld 1:/local:${pkgs.shadow}/bin/nologin" > "$root/etc/passwd"
              echo "nixbld1:$gid:100" > "$root/etc/subgid"
              echo "nixbld1:$uid:100" > "$root/etc/subuid"

              nsjail -Mo ${toString (lib.cli.toGNUCommandLine {} flags)} \
                --user "$uid" \
                --group "$gid" \
                ''${cgroupV2Mount:+--use_cgroupv2} \
                ''${cgroupV2Mount:+--cgroupv2_mount "$cgroupV2Mount"} \
                -- ${lib.escapeShellArg "${task.computedCommand}/bin/${config.name}"}
            '';
          };
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
          default = 30;
        };

        cloneNewnet = mkOption {
          type = bool;
          default = false;
        };

        cwd = mkOption {
          type = str;
          default = task.workingDir;
          description = "change to this directory before starting the script startup";
        };

        bindmount = mkOption {
          default = {};
          type = submodule {
            options = {
              rw = mkOption {
                type = listOf str;
                default = [];
              };

              ro = mkOption {
                type = listOf str;
                default = [];
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
                default = task.memory * 1024 * 1024;
                description = "Maximum number of bytes to use in the group. 0 is disabled";
              };

              pidsMax = mkOption {
                type = ints.unsigned;
                default = 0;
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
    };
  };
}
