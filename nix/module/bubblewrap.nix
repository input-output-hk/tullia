{
  lib,
  pkgs,
  config,
  writers,
  task,
  ...
}: let
  inherit (lib) mkOption mkEnableOption;
  inherit
    (lib.types)
    attrs
    listOf
    nullOr
    package
    str
    submodule
    ;

  transferContext = entries: let
    originalKey = lib.elemAt entries 0;
    originalValue = lib.elemAt entries 1;
    newKey = builtins.unsafeDiscardStringContext originalKey;
    newValue = lib.addContextFrom originalKey originalValue;
  in
    lib.nameValuePair newKey newValue;

  transferContexts = list: lib.listToAttrs (map transferContext list);

  flags = {
    # Setting `unshare-all` here sorts it after `share-net`,
    # apparently bubblewrap options depend on order.

    # unshare-all = true;
    # share-net = true;
    unshare-cgroup = true;
    unshare-cgroup-try = true;
    unshare-ipc = true;
    # unshare-net = true;
    unshare-pid = true;
    unshare-user = true;
    unshare-user-try = true;
    unshare-uts = true;

    die-with-parent = true;

    clearenv = true;
    chdir = "/repo";
    dev = "/dev";
    proc = "/proc";

    dir = [
      "/bin"
      "/etc"
      "/local"
      "/tmp"
      "/usr/bin"
      "/var"
    ];
    ro-bind = lib.listToAttrs (map
      (path: lib.nameValuePair (builtins.unsafeDiscardStringContext path) path)
      (config.closure.storePaths ++ ["/etc/resolv.conf"]));
    bind = {
      "$alloc" = "/alloc";
      "$PWD" = "/repo";
    };
    symlink = transferContexts [
      ["${pkgs.bash}/bin/sh" "/bin/sh"]
      ["${pkgs.coreutils}/usr/bin/env" "/usr/bin/env"]
    ];
    setenv = let
      caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    in {
      HOME = "/local";
      PS1 = "tullia: ";
      CURL_CA_BUNDLE = caBundle;
      NIX_SSL_CERT_FILE = caBundle;
      SSL_CERT_FILE = caBundle;
    };
  };

  join = key: values: lib.concatStringsSep " " [key (lib.escapeShellArgs values)];

  toFlags = k: v: let
    key = "--${k}";
    toValue =
      {
        string = join key [v];
        bool = key;
        list = map (vv: join key [vv]) v;
        set =
          lib.mapAttrsToList (
            kk: vv: let
              kkk = builtins.unsafeDiscardStringContext kk;
              vvv = lib.addContextFrom kk vv;
            in
              # Keys in attrs cannot have string context, so we have to move the context to the value.
              if lib.hasInfix "$" kk
              then lib.concatStringsSep " " [key ''"${kkk}"'' (lib.escapeShellArg vvv)]
              else join key [kkk vvv]
          )
          v;
      }
      .${builtins.typeOf v};
  in
    if v == null || v == false
    then []
    else toValue;

  finalFlags = lib.pipe flags [
    (lib.mapAttrsToList toFlags)
    lib.flatten
    (lib.remove null)
    (lib.concatStringsSep " \\\n  ")
  ];

  pp = a: __trace (__toJSON a) a;
in {
  options.bubblewrap = mkOption {
    default = {};
    type = submodule {
      options = {
        run = mkOption {
          type = package;
          description = "Execute the task in a bubblewrap sandbox";
          default = writers.shell {
            name = "${config.name}-bwrap";
            runtimeInputs = with pkgs; [coreutils bubblewrap];
            text = ''
              uid="''${UID:-$(id -u)}"
              gid="''${GID:-$(id -g)}"

              alloc="''${alloc:-$(mktemp -d -t alloc.XXXXXXXXXX)}"

              function finish {
                status="$?"
                rm -rf "$alloc"
                exit "$status"
              }
              trap finish EXIT


              (exec bwrap \
                ${finalFlags} \
                --dir "/run/user/$uid" \
                --setenv XDG_RUNTIME_DIR "/run/user/$uid" \
                --file 11 /etc/passwd \
                --file 12 /etc/group \
                ${lib.escapeShellArg "${task.computedCommand}/bin/${config.name}"}) \
              11< <(getent passwd "$uid" 65534) \
              12< <(getent group "$gid" 65534)
            '';
          };
        };

        flags = mkOption {
          default = {};
          type = submodule {
            options = {
              # add-seccomp-fd FD          Load and use seccomp rules from FD (repeatable)"
              as-pid-1 = mkEnableOption "Do not install a reaper process with PID=1";
              # bind-data FD DEST          "Copy from FD to file which is bind-mounted on DEST"
              # bind SRC DEST              "Bind mount the host path SRC on DEST"
              bind = mkOption {
                type = attrs;
                default = {};
                description = "Bind mount the host path SRC on DEST";
              };
              bind-try = mkOption {
                type = attrs;
                default = {};
                description = "Equal to --bind but ignores non-existent SRC";
              };
              # block-fd FD                "Block on FD until some data to read is available"
              # cap-add CAP                "Add cap CAP when running as privileged user"
              # cap-drop CAP               "Drop cap CAP when running as privileged user"
              chdir = mkOption {
                type = str;
                default = "/";
                description = "Change directory to DIR";
              };
              # chmod OCTAL PATH           "Change permissions of PATH (must already exist)"
              clearenv = mkEnableOption "Unset all environment variables";
              # dev-bind SRC DEST          "Bind mount the host path SRC on DEST, allowing device access"
              # dev-bind-try SRC DEST      "Equal to --dev-bind but ignores non-existent SRC"
              dev = mkOption {
                type = str;
                default = "/dev";
                description = "Mount new dev on DEST";
              };
              die-with-parent = mkEnableOption "Kills with SIGKILL child process (COMMAND) when bwrap or bwrap's parent dies.";
              dir = mkOption {
                type = listOf str;
                default = [];
                description = "Create dir at DEST";
              };
              exec-label = mkOption {
                type = str;
                default = "tullia";
                description = "Exec label for the sandbox";
              };
              # file FD DEST               "Copy from FD to destination DEST"
              # file-label LABEL           "File label for temporary sandbox content"
              # gid GID                    "Custom gid in the sandbox (requires --unshare-user or --userns)"
              hostname = mkOption {
                type = str;
                default = config.name;
                description = "Custom hostname in the sandbox (requires --unshare-uts)";
              };
              # info-fd FD                 "Write information about the running container to FD"
              # json-status-fd FD          "Write container status to FD as multiple JSON documents"
              lock-file = mkOption {
                type = nullOr str;
                default = null;
                description = "Take a lock on DEST while sandbox is running";
              };
              # mqueue DEST                "Mount new mqueue on DEST"
              new-session = mkEnableOption "Create a new terminal session";
              # perms OCTAL                "Set permissions of next argument (--bind-data, --file, etc.)"
              # pidns FD                   "Use this user namespace (as parent namespace if using --unshare-pid)"
              # proc DEST                  "Mount new procfs on DEST"
              # remount-ro DEST            "Remount DEST as readonly; does not recursively remount"
              # ro-bind-data FD DEST       "Copy from FD to file which is readonly bind-mounted on DEST"
              ro-bind = mkOption {
                type = attrs;
                default = {};
                description = "Bind mount the host path SRC readonly on DEST";
              };
              # ro-bind-try SRC DEST       "Equal to --ro-bind but ignores non-existent SRC"
              # seccomp FD                 "Load and use seccomp rules from FD (not repeatable)"
              # setenv VAR VALUE           "Set an environment variable"
              share-net = mkEnableOption "Retain the network namespace (can only combine with --unshare-all)";
              # symlink SRC DEST           "Create symlink at DEST with target SRC"
              # sync-fd FD                 "Keep this fd open while sandbox is running"
              # tmpfs DEST                 "Mount new tmpfs on DEST"
              # uid UID                    "Custom uid in the sandbox (requires --unshare-user or --userns)"
              # unsetenv VAR               "Unset an environment variable"
              unshare-all = mkEnableOption "Unshare every namespace we support by default";
              unshare-cgroup = mkEnableOption "Create new cgroup namespace";
              unshare-cgroup-try = mkEnableOption "Create new cgroup namespace if possible else continue by skipping it";
              unshare-ipc = mkEnableOption "Create new ipc namespace";
              unshare-net = mkEnableOption "Create new network namespace";
              unshare-pid = mkEnableOption "Create new pid namespace";
              unshare-user = mkEnableOption "Create new user namespace (may be automatically implied if not setuid)";
              unshare-user-try = mkEnableOption "Create new user namespace if possible else continue by skipping it";
              unshare-uts = mkEnableOption "Create new uts namespace";
              # userns2 FD                  = "After setup switch to this user namespace, only useful with --userns";
              # userns-block-fd FD          = "Block on FD until the user namespace is ready";
              # userns FD                   = "Use this user namespace (cannot combine with --unshare-user)";
            };
          };
        };
      };
    };
  };
}
