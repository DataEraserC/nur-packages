{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.agent2api;

  inherit (cfg) stateDir;

  useStateDirectory = builtins.dirOf stateDir == "/var/lib";

  serverExecutable =
    if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false";

  adminPasswordCredential = "admin-password";

  # `Environment=` performs no variable expansion, so the credential path cannot
  # be declared there; the password is read from the credential directory by a
  # wrapper instead of being copied into the writable state directory.
  startScript = pkgs.writeShellScript "agent2api-server-start" ''
    if [ -n "''${CREDENTIALS_DIRECTORY-}" ] && [ -r "$CREDENTIALS_DIRECTORY/${adminPasswordCredential}" ]; then
      AGENT2API_ADMIN_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/${adminPasswordCredential}")"
      export AGENT2API_ADMIN_PASSWORD
    fi
    exec ${serverExecutable}
  '';

  execStart = if cfg.adminPasswordFile != null then startScript else serverExecutable;
in
{
  options.services.dataEraserc.agent2api = {
    enable = lib.mkEnableOption "Agent2API multi-provider gateway";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.agent2api-server or null;
      description = ''
        Agent2API headless server package. Defaults to `pkgs.agent2api-server`,
        which is the repository version when the NUR overlay is applied.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Address the gateway binds to. The default keeps both the management
        panel and the OpenAI-compatible endpoint on loopback; the service stores
        provider credentials, so exposing it needs a firewall or a TLS
        terminating reverse proxy in front.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3065;
      description = ''
        Port of the OpenAI-compatible gateway (`/v1/*`). The management panel is
        served on the same port unless `panelPort` is set.
      '';
    };

    panelPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      example = 3066;
      description = ''
        Serve the management panel (interface and `/api/*`) on its own port, so
        that only the gateway port has to be reachable from the network. Must
        differ from `port`.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/agent2api";
      description = ''
        Writable directory holding the SQLite database (accounts, logs, request
        statistics) and the credential encryption key. Directories directly
        below <filename>/var/lib</filename> are created by systemd; any other
        path has to exist before the service starts.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "agent2api";
      description = ''
        User account under which the service runs. The account is created when
        the default is kept; otherwise it has to be defined elsewhere.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "agent2api";
      description = ''
        Group under which the service runs. The group is created when the
        default is kept; otherwise it has to be defined elsewhere.
      '';
    };

    adminUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "admin";
      description = ''
        Pre-provision the panel administrator instead of registering it through
        the login page on first visit. Requires `adminPasswordFile`.
      '';
    };

    adminPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/agent2api-admin-password";
      description = ''
        File containing the panel administrator password in plain text, loaded
        as a systemd credential. The password is turned into a bcrypt hash on
        startup and only the hash is stored, so rotating the file updates the
        account on the next restart. Requires `adminUser`.
      '';
    };

    allowNoKey = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Disable the gateway's fail-closed behaviour: `/v1/*` is served without
        any API key at all. Only for a trusted, network-isolated host; the
        default keeps the endpoint rejecting requests until an API key is
        created in the panel.
      '';
    };

    captcha = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the login page offers the upstream human verification widget.
        Disabling it is useful for a loopback-only deployment.
      '';
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Log at debug level.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the gateway (and panel) ports in the firewall.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/agent2api.env";
      description = "Environment file as defined in {manpage}`systemd.exec(5)`.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the service.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.dataEraserc.agent2api.package must be set when the service is enabled.";
      }
      {
        assertion = cfg.user == "agent2api" || builtins.hasAttr cfg.user config.users.users;
        message = ''
          services.dataEraserc.agent2api.user is set to "${cfg.user}", but that user is not
          defined. Keep the default to have the module create it, or define
          users.users."${cfg.user}".
        '';
      }
      {
        assertion = cfg.group == "agent2api" || builtins.hasAttr cfg.group config.users.groups;
        message = ''
          services.dataEraserc.agent2api.group is set to "${cfg.group}", but that group is not
          defined. Keep the default to have the module create it, or define
          users.groups."${cfg.group}".
        '';
      }
      {
        assertion = cfg.adminPasswordFile == null || cfg.adminUser != null;
        message = "services.dataEraserc.agent2api.adminPasswordFile requires adminUser to be set.";
      }
      {
        assertion = cfg.panelPort == null || cfg.panelPort != cfg.port;
        message = "services.dataEraserc.agent2api.panelPort must differ from port.";
      }
    ];

    users.users = lib.mkIf (cfg.user == "agent2api") {
      agent2api = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "Agent2API service user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "agent2api") {
      agent2api = { };
    };

    systemd.services.agent2api = {
      description = "Agent2API multi-provider gateway with OpenAI-compatible APIs";
      documentation = [ "https://github.com/aimod-cc/Agent2API" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        AGENT2API_PROXY_HOME = stateDir;
        AGENT2API_HOST = cfg.host;
        AGENT2API_PROXY_PORT = toString cfg.port;
        AGENT2API_CAPTCHA_ENABLED = if cfg.captcha then "1" else "0";
        AGENT2API_SELF_UPDATE = "0";
      }
      // lib.optionalAttrs (cfg.panelPort != null) {
        AGENT2API_PANEL_PORT = toString cfg.panelPort;
      }
      // lib.optionalAttrs (cfg.adminUser != null) {
        AGENT2API_ADMIN_USER = cfg.adminUser;
      }
      // lib.optionalAttrs cfg.allowNoKey {
        AGENT2API_ALLOW_NO_KEY = "1";
      }
      // lib.optionalAttrs cfg.verbose {
        AGENT2API_VERBOSE = "1";
      }
      // cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = execStart;
        Restart = "on-failure";
        RestartSec = 5;
        LoadCredential = lib.optionals (cfg.adminPasswordFile != null) [
          "${adminPasswordCredential}:${cfg.adminPasswordFile}"
        ];
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];

        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
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

    system.activationScripts.agent2api = lib.stringAfter [ "users" ] ''
      install -d -m 0700 ${lib.escapeShellArg stateDir}
      chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg stateDir}
    '';

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ] ++ lib.optional (cfg.panelPort != null) cfg.panelPort;
    };
  };
}
