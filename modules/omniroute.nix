{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.omniroute;

  inherit (cfg) stateDir;
  useStateDirectory = builtins.dirOf stateDir == "/var/lib";

  serverExecutable =
    if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false";
in
{
  options.services.dataEraserc.omniroute = {
    enable = lib.mkEnableOption "the OmniRoute unified LLM gateway";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.omniroute or null;
      description = "OmniRoute package to run. The default pkgs.omniroute only exists when an overlay providing it is applied.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "omniroute";
      description = "User account the service runs as. The default account is created automatically; any other name must already exist as a user.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "omniroute";
      description = "Group the service runs as. The default group is created automatically; any other name must already exist as a group.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the OmniRoute HTTP server binds to, exported as the upstream HOSTNAME variable. The default keeps the service loopback-only; set 0.0.0.0 to listen on all interfaces, and then turn on REQUIRE_API_KEY through extraEnvironment so the upstream non-loopback API key guard is satisfied.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 20128;
      description = "TCP port serving the OmniRoute dashboard and API.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/omniroute";
      description = "Directory holding all mutable state (SQLite database, generated server.env secrets and logs), exported as the upstream DATA_DIR variable. Paths under /var/lib are created by systemd StateDirectory=; other locations are pre-created by a NixOS activation script and must stay writable by the service user.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the configured service port in the firewall.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/omniroute.env";
      description = "Optional systemd environment file for the service, typically used to inject secrets such as an initial management password without committing them to the Nix store.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        REQUIRE_API_KEY = "true";
      };
      description = "Extra environment variables exported to the OmniRoute process. They cannot override HOSTNAME, PORT, DATA_DIR, NODE_ENV or NEXT_TELEMETRY_DISABLED, which this module derives from its own options.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.dataEraserc.omniroute.package must not be null; the default pkgs.omniroute requires an overlay that exposes the omniroute package.";
      }
      {
        assertion = cfg.user == "omniroute" || builtins.hasAttr cfg.user config.users.users;
        message = "services.dataEraserc.omniroute.user must name an existing user when it differs from the default omniroute account.";
      }
      {
        assertion = cfg.group == "omniroute" || builtins.hasAttr cfg.group config.users.groups;
        message = "services.dataEraserc.omniroute.group must name an existing group when it differs from the default omniroute group.";
      }
    ];

    users.users = lib.mkIf (cfg.user == "omniroute") {
      omniroute = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "OmniRoute gateway service";
      };
    };

    users.groups = lib.mkIf (cfg.group == "omniroute") {
      omniroute = { };
    };

    systemd.services.omniroute = {
      description = "OmniRoute unified LLM gateway";
      documentation = [ "https://github.com/diegosouzapw/OmniRoute" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = cfg.extraEnvironment // {
        HOSTNAME = cfg.host;
        PORT = toString cfg.port;
        DATA_DIR = stateDir;
        NODE_ENV = "production";
        NEXT_TELEMETRY_DISABLED = "1";
      };

      serviceConfig = {
        Type = "notify";
        NotifyAccess = "all";
        WatchdogSec = 120;
        User = cfg.user;
        Group = cfg.group;
        ExecStart = serverExecutable;
        Restart = "on-failure";
        RestartSec = 5;
        SuccessExitStatus = [ "143" ];
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
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
        StateDirectoryMode = "0700";
      }
      // lib.optionalAttrs (!useStateDirectory) {
        ReadWritePaths = [ stateDir ];
      };
    };

    system.activationScripts.omniroute = lib.stringAfter [ "users" ] ''
      install -d -m 0700 ${lib.escapeShellArg stateDir}
      chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg stateDir}
    '';

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
