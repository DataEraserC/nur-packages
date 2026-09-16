{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.m365Copilot2api;

  inherit (cfg) stateDir;
in
{
  options.services.dataEraserc.m365Copilot2api = {
    enable = lib.mkEnableOption "M365 Copilot2API gateway";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.m365-copilot2api or null;
      description = ''
        M365 Copilot2API server package. Defaults to `pkgs.m365-copilot2api`,
        which is the repository version when the NUR overlay is applied.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "m365-copilot2api";
      description = "User account under which the service runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "m365-copilot2api";
      description = "Group under which the service runs.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/m365-copilot2api";
      description = ''
        Writable state directory for accounts, tokens, sessions, API keys,
        settings, and other runtime data.
      '';
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:4141";
      description = ''
        Address the server binds to. Defaults to localhost; set to
        <literal>0.0.0.0:4141</literal> to expose the API and management
        console on the network.
      '';
    };

    adminPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/m365-admin-password";
      description = ''
        File containing the administrator password for the web console.
        When set, the password is loaded via systemd <literal>LoadCredential</literal>
        and injected through <literal>M365_ADMIN_PASSWORD_FILE</literal>.
        When null, an inline password from <option>adminPassword</option> is used.
      '';
    };

    adminPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Inline administrator password. Only used when
        <option>adminPasswordFile</option> is null. For production use,
        prefer <option>adminPasswordFile</option> or
        <option>extraEnvironment</option> with a secrets manager.
      '';
    };

    requireStrongPassword = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Require a strong admin password (12+ chars, mixed character classes).
        Set to false only for local/testing deployments.
      '';
    };

    accountConcurrency = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "Maximum number of simultaneous upstream calls per account.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for the configured listen port.";
    };

    autoCleanup = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable automatic cleanup of expired conversation data.";
    };

    cleanupMaxAgeHours = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Maximum age in hours for conversation data before cleanup.";
    };

    cleanupKeepN = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Number of recent conversations to keep per session after cleanup.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        {
          M365_LOG_LEVEL = "debug";
          M365_PROXY_POOL = "socks5://127.0.0.1:1080";
        }
      '';
      description = "Extra environment variables for the service.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/m365-copilot2api.env";
      description = "Environment file as defined in {manpage}`systemd.exec(5)`.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to the server command line (reserved for future use).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.dataEraserc.m365Copilot2api.package must be set when the service is enabled.";
      }
      {
        assertion = cfg.adminPasswordFile != null || cfg.adminPassword != null;
        message = "Either adminPasswordFile or adminPassword must be set for M365 Copilot2API.";
      }
    ];

    users.users = lib.mkIf (cfg.user == "m365-copilot2api") {
      m365-copilot2api = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "M365 Copilot2API service user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "m365-copilot2api") {
      m365-copilot2api = { };
    };

    systemd.services.m365-copilot2api = {
      description = "Microsoft 365 Copilot to OpenAI/Anthropic compatible API gateway";
      documentation = [ "https://github.com/HEXUXIU/M365-Copilot2API" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        M365_LISTEN = cfg.listenAddress;
        M365_DATA_DIR = stateDir;
        M365_ACCOUNT_DEFAULT_CONCURRENCY = toString cfg.accountConcurrency;
        M365_AUTO_CLEANUP = if cfg.autoCleanup then "true" else "false";
        M365_AUTO_CLEANUP_MAX_AGE_HOURS = toString cfg.cleanupMaxAgeHours;
        M365_AUTO_CLEANUP_KEEP_N = toString cfg.cleanupKeepN;
        M365_REQUIRE_STRONG_ADMIN_PASSWORD = if cfg.requireStrongPassword then "1" else "0";
      }
      // cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        StateDirectoryMode = "0700";
        WorkingDirectory = stateDir;
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        RestartSec = 5;
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];

        # Inject admin password via LoadCredential
        LoadCredential =
          lib.optional (cfg.adminPasswordFile != null) "admin-password:${cfg.adminPasswordFile}"
          ++ lib.optional (
            cfg.adminPasswordFile == null && cfg.adminPassword != null
          ) "admin-password-inline:${pkgs.writeText "admin-password" cfg.adminPassword}";

        # Hardening
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
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RemoveIPC = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        UMask = "0077";
      }
      // lib.optionalAttrs (stateDir == "/var/lib/m365-copilot2api") {
        StateDirectory = "m365-copilot2api";
      }
      // {
        ReadWritePaths = [ stateDir ];
      };

      preStart =
        if cfg.adminPasswordFile != null then
          ''
            export M365_ADMIN_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/admin-password"
          ''
        else if cfg.adminPassword != null then
          ''
            export M365_ADMIN_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/admin-password-inline"
          ''
        else
          "";
    };

    system.activationScripts.m365-copilot2api = lib.stringAfter [ "users" ] ''
      install -d -m 0700 ${lib.escapeShellArg stateDir}
      chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg stateDir}
    '';

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ (lib.head (lib.splitString ":" cfg.listenAddress)) ];
    };
  };
}
