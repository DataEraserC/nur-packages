{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.new-api;

  inherit (cfg) stateDir;

  # systemd creates directories directly below /var/lib; others need ReadWritePaths.
  useStateDirectory = builtins.dirOf stateDir == "/var/lib";

  # Build the SQL_DSN from structured options
  sqlDsn =
    if cfg.database.type == "sqlite" then
      ""
    else if cfg.database.type == "postgresql" then
      cfg.database.dsn
    else if cfg.database.type == "mysql" then
      cfg.database.dsn
    else
      "";

  logSqlDsn = if cfg.logDatabase.enable then cfg.logDatabase.dsn else "";

  environmentVars = {
    PORT = toString cfg.port;
    SQLITE_PATH = "${stateDir}/new-api.db";
    NODE_TYPE = if cfg.master then "master" else "slave";
    GIN_MODE = "release";
    LOG_DIR = "${stateDir}/logs";
  }
  // lib.optionalAttrs (sqlDsn != "") { SQL_DSN = sqlDsn; }
  // lib.optionalAttrs (logSqlDsn != "") { LOG_SQL_DSN = logSqlDsn; }
  // lib.optionalAttrs (cfg.redisUrl != null) { REDIS_CONN_STRING = cfg.redisUrl; }
  // lib.optionalAttrs cfg.memoryCache { MEMORY_CACHE_ENABLED = "true"; }
  // lib.optionalAttrs cfg.debug { DEBUG = "true"; }
  // cfg.extraEnvironment;

  # Wrap the binary with --log-dir pointing to stateDir
  serverArgv = [
    (if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false")
    "--port"
    (toString cfg.port)
    "--log-dir"
    "${stateDir}/logs"
  ]
  ++ cfg.extraArgs;

  # Resolve secrets from files at runtime via systemd credentials
  serverLauncher =
    let
      sessionSecretExport =
        if cfg.sessionSecret != null then
          "export SESSION_SECRET=${lib.escapeShellArg cfg.sessionSecret}"
        else if cfg.sessionSecretFile != null then
          ''export SESSION_SECRET="$(cat "$CREDENTIALS_DIRECTORY/session-secret")"''
        else
          "";
      cryptoSecretExport =
        if cfg.cryptoSecret != null then
          "export CRYPTO_SECRET=${lib.escapeShellArg cfg.cryptoSecret}"
        else if cfg.cryptoSecretFile != null then
          ''export CRYPTO_SECRET="$(cat "$CREDENTIALS_DIRECTORY/crypto-secret")"''
        else
          "";
    in
    pkgs.writeShellScript "new-api-start" ''
      ${sessionSecretExport}
      ${cryptoSecretExport}
      exec ${lib.escapeShellArgs serverArgv}
    '';
in
{
  options.services.dataEraserc.new-api = {
    enable = lib.mkEnableOption "new-api LLM gateway";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.new-api or null;
      description = ''
        new-api package. Defaults to `pkgs.new-api` when the NUR overlay is
        applied.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port the HTTP server listens on.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/new-api";
      description = ''
        Writable state directory for the SQLite database, logs, and other
        persistent data. Directories directly below
        <filename>/var/lib</filename> are created by systemd automatically.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "new-api";
      description = ''
        User account under which the service runs. Created automatically
        when using the default value.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "new-api";
      description = ''
        Group under which the service runs. Created automatically when
        using the default value.
      '';
    };

    master = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether this instance is the master node. Master nodes run database
        migrations and scheduled tasks. Set to <literal>false</literal> for
        read-replica / slave nodes.
      '';
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [
          "sqlite"
          "postgresql"
          "mysql"
        ];
        default = "sqlite";
        description = ''
          Database engine. When set to <literal>sqlite</literal>, the database
          file is stored in <option>stateDir</literal>. For PostgreSQL or
          MySQL, provide a DSN via <option>database.dsn</option>.
        '';
      };

      dsn = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "postgres://user:password@localhost:5432/newapi?sslmode=disable";
        description = ''
          Database connection string (DSN) for PostgreSQL or MySQL.
          Ignored when <option>database.type</option> is
          <literal>sqlite</literal>.

          For PostgreSQL the DSN must start with <literal>postgres://</literal>
          or <literal>postgresql://</literal>. For MySQL it should be the
          standard Go DSN format:
          <literal>user:password@tcp(host:port)/dbname</literal>.
        '';
      };
    };

    logDatabase = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable a separate log database (e.g. ClickHouse) for audit logs.
          When disabled, logs are stored in the main database.
        '';
      };

      dsn = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "clickhouse://default:password@localhost:9000/logs";
        description = ''
          Connection string for the log database. Typically a ClickHouse
          DSN starting with <literal>clickhouse://</literal>.
        '';
      };
    };

    redisUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "redis://localhost:6379/0";
      description = ''
        Redis connection URL for caching. When null, Redis is disabled and
        in-memory caching is used instead.
      '';
    };

    sessionSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/new-api-session-secret";
      description = ''
        Path to a file containing the session secret key. Loaded as a
        systemd credential at runtime. If null, the application default is
        used (not recommended for production). Mutually exclusive with
        <literal>sessionSecret</literal>.
      '';
    };

    sessionSecret = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "change-me-please";
      description = ''
        Session secret value supplied directly instead of via a file.
        Mutually exclusive with <literal>sessionSecretFile</literal>; the
        conflict is rejected by a module assertion. A plaintext value ends
        up in the Nix store because the launcher script is world-readable,
        so prefer <literal>sessionSecretFile</literal> for production. When
        both are null, the application default is used (not recommended
        for production). The literal value <literal>random_string</literal>
        is rejected at evaluation time because upstream refuses to start
        with it.
      '';
    };

    cryptoSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/new-api-crypto-secret";
      description = ''
        Path to a file containing the application encryption key
        (CRYPTO_SECRET), loaded as a systemd credential at runtime. When
        null, upstream derives the key from the session secret instead.
        Mutually exclusive with <literal>cryptoSecret</literal>.
      '';
    };

    cryptoSecret = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "change-me-please";
      description = ''
        Application encryption key value supplied directly instead of via
        a file (CRYPTO_SECRET). Mutually exclusive with
        <literal>cryptoSecretFile</literal>; the conflict is rejected by a
        module assertion. A plaintext value ends up in the Nix store
        because the launcher script is world-readable, so prefer
        <literal>cryptoSecretFile</literal> for production. When both are
        null, upstream derives the key from the session secret (falling
        back to a per-boot random value when that is also unset).
      '';
    };

    memoryCache = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable in-memory channel cache (recommended).";
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable debug mode with verbose logging.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the service port in the firewall.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/new-api.env";
      description = ''
        Environment file as defined in {manpage}`systemd.exec(5)`.
        Use this for secrets or overrides not covered by dedicated options.
      '';
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the service.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra command-line arguments passed to the server.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.dataEraserc.new-api.package must be set when the service is enabled.";
      }
      {
        assertion = cfg.user == "new-api" || builtins.hasAttr cfg.user config.users.users;
        message = ''
          services.dataEraserc.new-api.user is set to "${cfg.user}", but that
          user is not defined. Keep the default to have the module create it,
          or define users.users."${cfg.user}".
        '';
      }
      {
        assertion = cfg.group == "new-api" || builtins.hasAttr cfg.group config.users.groups;
        message = ''
          services.dataEraserc.new-api.group is set to "${cfg.group}", but that
          group is not defined. Keep the default to have the module create it,
          or define users.groups."${cfg.group}".
        '';
      }
      {
        assertion = cfg.database.type == "sqlite" || cfg.database.dsn != "";
        message = ''
          services.dataEraserc.new-api.database.type is "${cfg.database.type}"
          but database.dsn is empty. Please provide a connection string.
        '';
      }
      {
        assertion = !cfg.logDatabase.enable || cfg.logDatabase.dsn != "";
        message = ''
          services.dataEraserc.new-api.logDatabase.enable is true but
          logDatabase.dsn is empty. Please provide a log database connection
          string.
        '';
      }
      {
        assertion = cfg.sessionSecret == null || cfg.sessionSecretFile == null;
        message = ''
          services.dataEraserc.new-api.sessionSecret and
          services.dataEraserc.new-api.sessionSecretFile are mutually
          exclusive; set only one of them.
        '';
      }
      {
        assertion =
          !(cfg.extraEnvironment ? SESSION_SECRET)
          || (cfg.sessionSecret == null && cfg.sessionSecretFile == null);
        message = ''
          services.dataEraserc.new-api.extraEnvironment.SESSION_SECRET
          conflicts with services.dataEraserc.new-api.sessionSecret or
          .sessionSecretFile; set the session secret through only one input.
        '';
      }
      {
        assertion = cfg.sessionSecret != "random_string";
        message = ''
          services.dataEraserc.new-api.sessionSecret is set to the literal
          value "random_string", which upstream new-api refuses to start
          with (log.Fatal); choose a random string instead.
        '';
      }
      {
        assertion = cfg.cryptoSecret == null || cfg.cryptoSecretFile == null;
        message = ''
          services.dataEraserc.new-api.cryptoSecret and
          services.dataEraserc.new-api.cryptoSecretFile are mutually
          exclusive; set only one of them.
        '';
      }
      {
        assertion =
          !(cfg.extraEnvironment ? CRYPTO_SECRET)
          || (cfg.cryptoSecret == null && cfg.cryptoSecretFile == null);
        message = ''
          services.dataEraserc.new-api.extraEnvironment.CRYPTO_SECRET
          conflicts with services.dataEraserc.new-api.cryptoSecret or
          .cryptoSecretFile; set the crypto secret through only one input.
        '';
      }
    ];

    users.users = lib.mkIf (cfg.user == "new-api") {
      new-api = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "new-api service user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "new-api") {
      new-api = { };
    };

    systemd.services.new-api = {
      description = "OpenAI-compatible LLM gateway with users, API tokens, quotas and usage logs";
      documentation = [ "https://github.com/QuantumNous/new-api" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = environmentVars;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = serverLauncher;
        Restart = "on-failure";
        RestartSec = 5;
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
        LoadCredential =
          lib.optionals (cfg.sessionSecretFile != null) [ "session-secret:${cfg.sessionSecretFile}" ]
          ++ lib.optionals (cfg.cryptoSecretFile != null) [ "crypto-secret:${cfg.cryptoSecretFile}" ];

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

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
