{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.our-free-model-standalone;

  inherit (cfg) stateDir;

  # systemd creates directories directly below /var/lib; others have to exist
  # already (ProtectSystem=strict makes ReadWritePaths fail on a missing path).
  useStateDirectory = builtins.dirOf stateDir == "/var/lib";

  # Keep the evaluation alive when the package is missing so that the
  # assertions below can report it instead of lib.getExe crashing.
  serverExecutable =
    if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false";

  startArgs = [
    "--data-dir"
    stateDir
    "--port"
    (toString cfg.port)
  ]
  ++ lib.optional (!cfg.refresh) "--no-refresh";

  # A crash leaves service.lock behind and every later start fails with
  # EEXIST, wedging Restart=on-failure forever. Drop the lock only when its
  # recorded owner is really gone; a live owner keeps refusing the start so
  # two instances can never share one data directory.
  removeStaleLock = pkgs.writeShellScript "our-free-model-standalone-remove-stale-lock" ''
    lock=${lib.escapeShellArg "${stateDir}/service.lock"}
    if [ ! -e "$lock" ]; then
      exit 0
    fi
    pid=$(${pkgs.gnused}/bin/sed -n 's/.*"pid":\([0-9][0-9]*\).*/\1/p' "$lock")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "our-free-model-standalone: $lock is held by running process $pid" >&2
      echo "stop that instance first; only one instance may use ${stateDir}" >&2
      exit 1
    fi
    ${pkgs.coreutils}/bin/rm -f "$lock"
  '';
in
{
  options.services.dataEraserc.our-free-model-standalone = {
    enable = lib.mkEnableOption "the Our Free Model standalone free-model gateway";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.dsh-our-free-model-standalone or null;
      description = ''
        Our Free Model standalone gateway package. Defaults to
        `pkgs.dsh-our-free-model-standalone`, which is the repository version
        when the NUR overlay is applied.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "our-free-model-standalone";
      description = ''
        User account under which the service runs. When changed from the
        default the account has to be defined elsewhere.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "our-free-model-standalone";
      description = ''
        Group under which the service runs. When changed from the default the
        group has to be defined elsewhere.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/our-free-model-standalone";
      description = ''
        Writable data directory for the account pool, credentials, settings,
        and the API key. Directories outside <filename>/var/lib</filename>
        have to exist beforehand. The same directory must never be shared by
        two instances (the service enforces this with a lock file).
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 18900;
      description = ''
        Loopback TCP port the gateway binds. The service only ever listens on
        <literal>127.0.0.1</literal> (the upstream entry point rejects any
        other host), so exposing it to other machines means putting a reverse
        proxy in front. If the port is busy the upstream code walks to the
        next free one and logs the port it actually took, so check the
        management URL in the journal when the port does not respond.
      '';
    };

    refresh = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to refresh the model catalog at startup and periodically.
        Disable to pass <literal>--no-refresh</literal>, which skips all
        automatic upstream requests while manual refresh and inference keep
        working; probing can still be toggled on the web settings page.
      '';
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        HTTP_PROXY = "http://127.0.0.1:7890";
      };
      description = ''
        Extra environment variables for the service, such as proxy variables
        honored by some account channels. They cannot override
        <literal>HOME</literal>, which this module derives from
        <option>stateDir</option>; the data directory and port are passed as
        command line flags and win over <literal>OFM_HOME</literal>.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/our-free-model-standalone.env";
      description = ''
        Environment file as defined in {manpage}`systemd.exec(5)`, for secrets
        that should not be declared through <option>extraEnvironment</option>.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = ''
          services.dataEraserc.our-free-model-standalone.package must be set when the service is
          enabled (the NUR overlay is not applied and this nixpkgs provides no
          dsh-our-free-model-standalone).
        '';
      }
      {
        assertion = cfg.user == "our-free-model-standalone" || builtins.hasAttr cfg.user config.users.users;
        message = ''
          services.dataEraserc.our-free-model-standalone.user is set to "${cfg.user}", but that user is not
          defined. Keep the default to have the module create it, or define
          users.users."${cfg.user}".
        '';
      }
      {
        assertion =
          cfg.group == "our-free-model-standalone" || builtins.hasAttr cfg.group config.users.groups;
        message = ''
          services.dataEraserc.our-free-model-standalone.group is set to "${cfg.group}", but that group is not
          defined. Keep the default to have the module create it, or define
          users.groups."${cfg.group}".
        '';
      }
    ];

    users.users = lib.mkIf (cfg.user == "our-free-model-standalone") {
      our-free-model-standalone = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "Our Free Model standalone gateway service";
      };
    };

    users.groups = lib.mkIf (cfg.group == "our-free-model-standalone") {
      our-free-model-standalone = { };
    };

    systemd.services.our-free-model-standalone = {
      description = "Our Free Model standalone free-model gateway";
      documentation = [ "https://github.com/Ebony-Vinyl/dsh-our-free-model" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = "${removeStaleLock}";

      environment = {
        HOME = stateDir;
      }
      // cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = lib.escapeShellArgs ([ serverExecutable ] ++ startArgs);
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectoryMode = "0700";
        WorkingDirectory = stateDir;
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];

        # MemoryDenyWriteExecute is intentionally absent: V8 flips its JIT code
        # pages from r-x to rw during Isolate::Initialize and node dies
        # immediately under that setting.
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateUsers = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RemoveIPC = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        UMask = "0077";
      }
      // lib.optionalAttrs useStateDirectory {
        StateDirectory = [ (builtins.baseNameOf stateDir) ];
      }
      // lib.optionalAttrs (!useStateDirectory) {
        ReadWritePaths = [ stateDir ];
      };
    };

    system.activationScripts."our-free-model-standalone" = lib.stringAfter [ "users" ] ''
      install -d -m 0700 ${lib.escapeShellArg stateDir}
      chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg stateDir}
    '';
  };
}
