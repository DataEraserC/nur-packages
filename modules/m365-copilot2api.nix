{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.m365Copilot2api;

  inherit (cfg) stateDir;

  # systemd can only create the state directory when it lives directly below
  # /var/lib; anything else has to exist already (ProtectSystem=strict makes
  # ReadWritePaths fail on a missing path).
  useStateDirectory = builtins.dirOf stateDir == "/var/lib";

  # The server chdir()s to the directory of its own executable, so every
  # persisted path has to be absolute and outside the read-only store.
  dataPath = name: "${stateDir}/${name}";

  # Keep the evaluation alive when the package is missing so that the
  # assertions below can report it instead of lib.getExe crashing.
  serverExecutable =
    if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false";

  startScript = pkgs.writeShellScript "m365-copilot2api-start" ''
    set -eu
    ${lib.optionalString (cfg.adminPasswordFile != null) ''
      export M365_ADMIN_PASSWORD_BOOTSTRAP_FILE="$CREDENTIALS_DIRECTORY/admin-password"
    ''}
    ${lib.optionalString (cfg.masterKeyFile != null) ''
      export M365_MASTER_KEY="$(cat "$CREDENTIALS_DIRECTORY/master-key")"
    ''}
    exec ${serverExecutable}
  '';

  # The server reads admin-password.json first and only falls back to the
  # bootstrap credential when no persisted password exists, so a rotated
  # credential has to invalidate the persisted file explicitly.
  seedAdminPassword = pkgs.writeShellScript "m365-copilot2api-seed-admin-password" ''
    set -eu
    credential="$CREDENTIALS_DIRECTORY/admin-password"
    marker=${lib.escapeShellArg (dataPath ".admin-password.sha256")}
    if [ ! -s "$credential" ]; then
      exit 0
    fi
    current="$(sha256sum "$credential" | cut -d' ' -f1)"
    previous="$(cat "$marker" 2>/dev/null || true)"
    if [ "$current" != "$previous" ]; then
      rm -f ${lib.escapeShellArg (dataPath "admin-password")} ${lib.escapeShellArg (dataPath "admin-password.json")}
      printf '%s\n' "$current" > "$marker"
      chmod 0600 "$marker"
    fi
  '';
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
      description = ''
        User account under which the service runs. When changed from the
        default the account has to be defined elsewhere.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "m365-copilot2api";
      description = ''
        Group under which the service runs. When changed from the default the
        group has to be defined elsewhere.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/m365-copilot2api";
      description = ''
        Writable state directory for accounts, tokens, sessions, API keys,
        settings, and other runtime data. Directories outside
        <filename>/var/lib</filename> have to exist beforehand.
      '';
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Address the server binds to. Use the bracketed form for IPv6, for
        example <literal>[::1]</literal>.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4141;
      description = "TCP port the server binds to.";
    };

    adminPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/m365-admin-password";
      description = ''
        File containing the administrator password for the web console as
        plain text, loaded as a systemd credential. It seeds the password on
        first start and again whenever its content changes; a password changed
        from the web console stays in effect until then.
      '';
    };

    masterKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/m365-master-key";
      description = ''
        File containing the key used to encrypt account refresh tokens in
        <filename>accounts.json</filename>, loaded as a systemd credential.
        Without it the server falls back to a built-in public key. Existing
        tokens have to be authorized again before enabling this option.
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
      description = ''
        Whether to open the configured port in the firewall. The web console
        is served over plain HTTP, so expose it to the network only behind a
        TLS terminating reverse proxy.
      '';
    };

    autoCleanup = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the periodic cleanup of expired conversation data.";
    };

    autoCleanupMaxAgeHours = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Maximum age in hours for conversation data before the periodic cleanup removes it.";
    };

    autoCleanupKeepN = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Number of recent conversations the periodic cleanup keeps.";
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
      description = ''
        Environment file as defined in {manpage}`systemd.exec(5)`. May be used
        instead of <option>adminPasswordFile</option> to supply
        <literal>M365_ADMIN_PASSWORD</literal>.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.dataEraserc.m365Copilot2api.package must be set when the service is enabled.";
      }
      {
        assertion = cfg.adminPasswordFile != null || cfg.environmentFile != null;
        message = ''
          services.dataEraserc.m365Copilot2api requires adminPasswordFile, or an
          environmentFile providing M365_ADMIN_PASSWORD.
        '';
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
        M365_LISTEN = "${cfg.listenAddress}:${toString cfg.port}";
        M365_DATA_DIR = stateDir;
        M365_CONFIG = dataPath "accounts.json";
        M365_TOKEN_CACHE = dataPath "token-cache.json";
        M365_SESSION_CACHE = dataPath "sessions.json";
        M365_USER_SESSION_CACHE = dataPath "user-sessions.json";
        M365_CONVERSATION_CACHE = dataPath "conversations.json";
        M365_API_KEYS = dataPath "api-keys.json";
        M365_USAGE_LOG = dataPath "usage.jsonl";
        M365_DEBUG_LOG = dataPath "debug-logs.jsonl";
        M365_ACCOUNT_DEFAULT_CONCURRENCY = toString cfg.accountConcurrency;
        M365_AUTO_CLEANUP = lib.boolToString cfg.autoCleanup;
        M365_AUTO_CLEANUP_MAX_AGE_HOURS = toString cfg.autoCleanupMaxAgeHours;
        M365_AUTO_CLEANUP_KEEP_N = toString cfg.autoCleanupKeepN;
        M365_REQUIRE_STRONG_ADMIN_PASSWORD = "1";
      }
      // cfg.extraEnvironment;

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        StateDirectoryMode = "0700";
        ExecStart = startScript;
        ExecStartPre = lib.optional (cfg.adminPasswordFile != null) "+${seedAdminPassword}";
        Restart = "on-failure";
        RestartSec = 5;
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];

        LoadCredential =
          lib.optional (cfg.adminPasswordFile != null) "admin-password:${cfg.adminPasswordFile}"
          ++ lib.optional (cfg.masterKeyFile != null) "master-key:${cfg.masterKeyFile}";

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
          "AF_UNIX"
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
      // lib.optionalAttrs useStateDirectory {
        StateDirectory = builtins.baseNameOf stateDir;
      }
      // lib.optionalAttrs (!useStateDirectory) {
        ReadWritePaths = [ stateDir ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
