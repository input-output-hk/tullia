{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  task.postgres = let
    hba = pkgs.writeText "hba.conf" ''
      local all all           trust
      host  all all 0.0.0.0/0 trust
      host  all all ::1/0     trust
    '';

    ident = pkgs.writeText "ident.conf" " ";

    pgconf = pkgs.writeText "pg.conf" ''
      data_directory = '/local/data'
      external_pid_file = '/alloc/.s.PGSQL.5432.lock'
      hba_file = '${hba}'
      ident_file = '${ident}'
      listen_addresses = '0.0.0.0,::1'
      log_destination = 'stderr'
      log_line_prefix = '[%p] '
      log_statement = 'all'
      max_locks_per_transaction = 1024
      pg_stat_statements.track = 'all'
      shared_preload_libraries = 'pg_stat_statements'
      unix_socket_directories = '/alloc'
    '';
  in {
    inputs = [
      pkgs.postgresql
      # because postgres requires /bin/sh
      (pkgs.symlinkJoin {
        name = "root";
        paths = [pkgs.bashInteractive];
      })
    ];

    command = ''
      set -exuo pipefail
      mkdir -p /local/data
      chmod 0700 /local/data
      initdb --pgdata=/local/data
      exec postgres --config-file=${pgconf} "$@"
    '';
  };

  task.migrate = {
    command = ''
      echo '\d' | pgcli -h /alloc
    '';
  };

  task.tidy = {
    inputs = [pkgs.go pkgs.gcc];
    command = ''
      cd /repo
      set -x
      go mod tidy -v
    '';
  };

  task.lint = {
    inputs = [pkgs.go pkgs.golangci-lint pkgs.gcc];
    after = [config.task.tidy];
    command = ''
      cd /repo
      set -x
      golangci-lint run
    '';
  };

  task.a.command = "echo a";

  task.b = {
    command = ''
      curl https://example.com
      aspell -d en dump master | aspell -l en expand | head -100 | randtype -t 50,100
    '';
    env.ASPELL_CONF = "dict-dir ${pkgs.aspellDicts.en}/lib/aspell";
    inputs = with pkgs; [randtype aspell];
    after = [config.task.a config.task.memtest];
  };

  task.c = {
    command = "echo 'c -> b'";
    after = [config.task.b];
  };

  task.d = {
    command = "echo d -> b,c";
    after = [config.task.c config.task.b];
  };

  task.e = {
    command = "echo e; exit 1";
    after = [config.task.c config.task.d];
  };

  task.f = {
    command = "echo f";
    after = [config.task.e];
  };

  task.memtest = {
    command = ''
      ${pkgs.ruby}/bin/ruby -e 'puts Array.new(10_000_000, "a").join.size'
      echo allocation done
    '';
    oci.layers = [pkgs.ruby];
    oci.maxLayers = 16;
  };

  task.push = {
    preset = "nix";
    command = "${config.task.ci.oci.image.copyToRegistry}/bin/copy-to-registry";
  };

  task.ci = {
    preset = "nix";
    nomad.config.driver = "podman";
    nomad.config.image = "${config.task.ci.oci.name}:${config.task.ci.oci.tag}";
    after = [config.task.push];

    command = ''
      set -exuo pipefail

      cd /repo
      nix flake lock --update-input bitte

      for name in $(nix eval --raw .#nixosConfigurations --apply '(c: toString (builtins.attrNames c))'); do
        nix build ".#nixosConfigurations.$name.config.system.build.toplevel"
        ls -la result
      done
    '';

    env = {
      NIX_CONFIG = ''
        experimental-features = ca-derivations flakes nix-command
        log-lines = 1000
        show-trace = true
        sandbox = false
        substituters = http://alpha.fritz.box:7745/
        trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM= hercules-ci.cachix.org-1:ZZeDl9Va+xe9j+KqdzoBZMFJHVQ42Uu/c/1/KMC5Lw0= hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ= kappa:Ffd0MaBUBrRsMCHsQ6YMmGO+tlh7EiHRFK2YfOTSwag= manveru.cachix.org-1:L5nJHSinfA2K5dDCG3KAEadwf/e3qqhuBr7yCwSksXo=
        post-build-hook = ${pkgs.writeShellScript "copy-to-spongix" ''
          set -uf
          export IFS=' '
          if [[ -n "$OUT_PATHS" ]]; then
            echo "Uploading $OUT_PATHS"
            exec ${pkgs.nix}/bin/nix copy --to 'http://alpha.fritz.box:7745/?compression=none' $OUT_PATHS
          fi
        ''}
      '';
    };

    memory = 1024 * 8;
    nsjail.mount."/tmp".options.size = 2 * 1024;
    oci.maxLayers = 2;
    oci.name = "docker.infra.aws.iohkdev.io/bitte/ci";
    oci.tag = inputs.self.rev or "latest";
  };

  job.ci.group.ci.task.ci = config.task.ci;

  action.ci = {
    inputs.start."input-output-hk/bitte/ci".start = ''
      "input-output-hk/bitte/ci": start: {
        clone_url: string
        sha: string
        statuses_url?: string
      }
    '';

    # user defines:
    inputs.start."input-output-hk/bitte/ci".start = {
      clone_url = str;
      sha = str;
      statuses_url = nullOr str;
    };

    # evaluator gets input:
    # translate inputs

    # evaluator sets input:
    inputs.start."input-output-hk/bitte/ci".start = builtins.fromJSON ''{"clone_url": "foo"}'';

    output = {};
    # output."input-output-hk/bitte/ci".success = {
    #   ok = true;
    #   inherit (config.action.ci.inputs.start."input-output-hk/bitte/ci".start) clone_url sha;
    # };

    job.ci = config.job.ci;
    job.ci.env.SHA = config.action.ci.inputs.start."input-output-hk/bitte/ci".start.sha;
  };

  action.deploy = {
    # inputs."input-output-hk/bitte/ci".ok = true;
    # output."input-output-hk/bitte/deploy".onSuccess.ok = true;
    job = config.job.deploy;
  };
}
