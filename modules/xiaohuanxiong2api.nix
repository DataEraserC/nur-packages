{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.xiaohuanxiong2api;
  format = pkgs.formats.json { };

  inherit (cfg) stateDir;

  # systemd can only create the state directory when it lives directly below
  # /var/lib; anything else has to exist already (ProtectSystem=strict makes
  # ReadWritePaths fail on a missing path).
  useStateDirectory = builtins.dirOf stateDir == "/var/lib";

  # The upstream server reads its JSONC configuration once at startup and never
  # writes it back, so the generated file can stay in the store. Only the
  # account pool, model catalog cache and checkin history are rewritten, and
  # they are pinned below to absolute paths inside stateDir.
  accountsPath = "${stateDir}/accounts.json";
  catalogCachePath = "${stateDir}/model_catalog.json";
  checkinHistoryPath = "${stateDir}/checkin.json";

  listen =
    if lib.hasInfix ":" cfg.host && !(lib.hasPrefix "[" cfg.host) then
      "[${cfg.host}]:${toString cfg.port}"
    else
      "${cfg.host}:${toString cfg.port}";

  hasPath =
    attrs: path:
    let
      head = builtins.head path;
      tail = builtins.tail path;
    in
    lib.isAttrs attrs && builtins.hasAttr head attrs && (tail == [ ] || hasPath attrs.${head} tail);

  managedSettingPaths = [
    [ "listen" ]
    [ "api_key" ]
    [
      "accounts"
      "file"
    ]
    [
      "models"
      "catalog_cache_file"
    ]
    [
      "checkin"
      "history_file"
    ]
    [
      "admin"
      "api_key"
    ]
  ];
  managedSettingKeys = map (lib.concatStringsSep ".") (
    builtins.filter (path: hasPath cfg.settings path) managedSettingPaths
  );

  mergeSection =
    name: updates:
    if !(builtins.hasAttr name cfg.settings) then
      updates
    else if lib.isAttrs cfg.settings.${name} then
      cfg.settings.${name} // updates
    else
      throw "services.dataEraserc.xiaohuanxiong2api.settings.${name} must be an object";

  renderedSettings = cfg.settings // {
    inherit listen;
    accounts = mergeSection "accounts" { file = accountsPath; };
    models = mergeSection "models" { catalog_cache_file = catalogCachePath; };
    checkin = mergeSection "checkin" { history_file = checkinHistoryPath; };
  };

  configPath = format.generate "xiaohuanxiong2api-config.json" renderedSettings;

  # Keep the evaluation alive when the package is missing so that the
  # assertions below can report it instead of lib.getExe crashing.
  serverExecutable =
    if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false";

  # XHX_LISTEN / XHX_API_KEY / XHX_ADMIN_API_KEY are the only environment
  # overrides the server honours; the keys are exported from systemd
  # credentials so that they never enter the store or the unit's Environment=.
  startScript = pkgs.writeShellScript "xiaohuanxiong2api-start" ''
    set -eu
    ${lib.optionalString (cfg.apiKeyFile != null) ''
      if [ -s "$CREDENTIALS_DIRECTORY/api-key" ]; then
        XHX_API_KEY="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/api-key")"
        export XHX_API_KEY
      fi
    ''}
    ${lib.optionalString (cfg.adminApiKeyFile != null) ''
      if [ -s "$CREDENTIALS_DIRECTORY/admin-api-key" ]; then
        XHX_ADMIN_API_KEY="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/admin-api-key")"
        export XHX_ADMIN_API_KEY
      fi
    ''}
    exec ${serverExecutable} -config ${lib.escapeShellArg configPath}
  '';

  # The account pool is rewritten whenever a token refreshes, so the seeded
  # copy has to be a regular writable file owned by the service user. Systemd
  # credentials are already owned by that user, so ExecStartPre runs without
  # the "+" privilege prefix.
  seedAccountsScript = pkgs.writeShellScript "xiaohuanxiong2api-seed-accounts" ''
    set -eu
    target=${lib.escapeShellArg accountsPath}
    source="$CREDENTIALS_DIRECTORY/seed-accounts"
    if [ ! -s "$target" ] && [ -s "$source" ]; then
      ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg stateDir}
      ${pkgs.coreutils}/bin/install -m 0600 "$source" "$target"
    fi
  '';

  loopbackHosts = [
    "127.0.0.1"
    "::1"
    "localhost"
  ];
  # The XHX_* variables take precedence over the generated file; a runtime
  # environment file is assumed to carry them if the dedicated options are
  # unset.
  apiKeyConfigured =
    cfg.apiKeyFile != null || cfg.extraEnvironment ? XHX_API_KEY || cfg.environmentFile != null;
  adminKeyConfigured =
    cfg.adminApiKeyFile != null
    || cfg.extraEnvironment ? XHX_ADMIN_API_KEY
    || cfg.environmentFile != null;
  adminSettings = if lib.isAttrs (cfg.settings.admin or null) then cfg.settings.admin else { };
  adminEnabled = (adminSettings.enabled or true) == true;
in
{
  options.services.dataEraserc.xiaohuanxiong2api = {
    enable = lib.mkEnableOption "xiaohuanxiong2api gateway";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.xiaohuanxiong2api or null;
      description = ''
        xiaohuanxiong2api server package. Defaults to `pkgs.xiaohuanxiong2api`,
        which is the repository version when the NUR overlay is applied.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "xiaohuanxiong2api";
      description = ''
        User account under which the service runs. When changed from the
        default the account has to be defined elsewhere.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "xiaohuanxiong2api";
      description = ''
        Group under which the service runs. When changed from the default the
        group has to be defined elsewhere.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/xiaohuanxiong2api";
      description = ''
        Writable state directory holding <filename>accounts.json</filename>,
        <filename>model_catalog.json</filename> and
        <filename>checkin.json</filename>. Directories outside
        <filename>/var/lib</filename> have to exist beforehand and cannot live
        under <filename>/home</filename> because the unit sets
        <literal>ProtectHome=true</literal>.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Address the gateway listens on. Defaults to localhost; set to
        `0.0.0.0` to expose the OpenAI-compatible API and the management panel
        on the network.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3066;
      description = "TCP port the gateway and the management panel listen on (also used by `openFirewall`).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to open the configured port in the firewall. The API and the
        panel are served over plain HTTP, so expose them only behind a TLS
        terminating reverse proxy.
      '';
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/xiaohuanxiong2api-api-key";
      description = ''
        File containing the bearer key required on <literal>/v1</literal>,
        loaded as a systemd credential and exported as
        <literal>XHX_API_KEY</literal>. When unset (and no environment
        override supplies the key) the upstream server leaves
        <literal>/v1</literal> unauthenticated, matching its empty
        <literal>api_key</literal> default.
      '';
    };

    adminApiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/xiaohuanxiong2api-admin-api-key";
      description = ''
        File containing the key required by the management panel, loaded as a
        systemd credential and exported as
        <literal>XHX_ADMIN_API_KEY</literal>. When unset the upstream server
        leaves the panel read endpoints unauthenticated and rejects write
        operations with HTTP 403.
      '';
    };

    seedAccountsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/xiaohuanxiong2api-accounts.json";
      description = ''
        File containing the initial account pool (<literal>{"accounts": [...]}
        </literal>). It is loaded as a systemd credential and copied to
        <filename>${stateDir}/accounts.json</filename> only while that file is
        missing or empty; afterwards the server owns the file and rewrites it
        on token refresh, so later edits here do not reset it. Accounts can
        also be added through the management panel instead.
      '';
    };

    settings = lib.mkOption {
      inherit (format) type;
      default = { };
      example = lib.literalExpression ''
        {
          accounts.strategy = "priority";
          models.default = "sn-glm-5-3-flash";
          admin.title = "小浣熊反代";
          checkin.enabled = false;
        }
      '';
      description = ''
        Application configuration written to the generated JSON config file.
        Keys not listed here keep their upstream defaults. Relative paths
        resolve against <option>stateDir</option>, the service working
        directory; only that directory is writable.

        <literal>listen</literal>, <literal>api_key</literal>,
        <literal>accounts.file</literal>,
        <literal>models.catalog_cache_file</literal>,
        <literal>checkin.history_file</literal> and
        <literal>admin.api_key</literal> are owned by dedicated options and
        must not appear here.
      '';
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        {
          XHX_LISTEN = "0.0.0.0:3066";
        }
      '';
      description = ''
        Extra environment variables for the service. The server lets
        <literal>XHX_LISTEN</literal>, <literal>XHX_API_KEY</literal>,
        <literal>XHX_ADMIN_API_KEY</literal> and
        <literal>XHX_CONFIG</literal> override the generated configuration at
        runtime; prefer <option>host</option>/<option>port</option>,
        <option>apiKeyFile</option> and <option>adminApiKeyFile</option>, and
        note that <literal>XHX_CONFIG</literal> bypasses the managed state
        paths as well.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/xiaohuanxiong2api.env";
      description = "Environment file as defined in {manpage}`systemd.exec(5)`.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.dataEraserc.xiaohuanxiong2api.package must be set when the service is enabled.";
      }
      {
        assertion = cfg.user == "xiaohuanxiong2api" || builtins.hasAttr cfg.user config.users.users;
        message = ''
          services.dataEraserc.xiaohuanxiong2api.user is set to "${cfg.user}", but that user is not
          defined. Keep the default to have the module create it, or define
          users.users."${cfg.user}".
        '';
      }
      {
        assertion = cfg.group == "xiaohuanxiong2api" || builtins.hasAttr cfg.group config.users.groups;
        message = ''
          services.dataEraserc.xiaohuanxiong2api.group is set to "${cfg.group}", but that group is not
          defined. Keep the default to have the module create it, or define
          users.groups."${cfg.group}".
        '';
      }
      {
        assertion = managedSettingKeys == [ ];
        message = ''
          settings contains ${lib.concatStringsSep ", " managedSettingKeys}; these keys are owned
          by dedicated options. Use host/port, apiKeyFile, adminApiKeyFile, and stateDir instead.
        '';
      }
      {
        assertion = cfg.apiKeyFile == null || lib.hasPrefix "/" cfg.apiKeyFile;
        message = "services.dataEraserc.xiaohuanxiong2api.apiKeyFile must be an absolute path.";
      }
      {
        assertion = cfg.adminApiKeyFile == null || lib.hasPrefix "/" cfg.adminApiKeyFile;
        message = "services.dataEraserc.xiaohuanxiong2api.adminApiKeyFile must be an absolute path.";
      }
      {
        assertion = cfg.seedAccountsFile == null || lib.hasPrefix "/" cfg.seedAccountsFile;
        message = "services.dataEraserc.xiaohuanxiong2api.seedAccountsFile must be an absolute path.";
      }
    ];

    warnings =
      lib.optional (!lib.elem cfg.host loopbackHosts && !apiKeyConfigured)
        "xiaohuanxiong2api is listening beyond loopback without any /v1 API key; configure apiKeyFile or protect it behind an authenticated TLS reverse proxy."
      ++
        lib.optional (!lib.elem cfg.host loopbackHosts && adminEnabled && !adminKeyConfigured)
          "xiaohuanxiong2api exposes the management panel beyond loopback without an admin API key; configure adminApiKeyFile or disable settings.admin.enabled.";

    users.users = lib.mkIf (cfg.user == "xiaohuanxiong2api") {
      xiaohuanxiong2api = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "xiaohuanxiong2api service user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "xiaohuanxiong2api") {
      xiaohuanxiong2api = { };
    };

    systemd.services.xiaohuanxiong2api = {
      description = "SenseTime Raccoon OpenAI-compatible reverse proxy";
      documentation = [ "https://github.com/haoxinyu1/xiaohuanxiong2api" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = stateDir;
        ExecStart = startScript;
        ExecStartPre = lib.optional (cfg.seedAccountsFile != null) seedAccountsScript;
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectoryMode = "0700";
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];

        LoadCredential =
          lib.optional (cfg.apiKeyFile != null) "api-key:${cfg.apiKeyFile}"
          ++ lib.optional (cfg.adminApiKeyFile != null) "admin-api-key:${cfg.adminApiKeyFile}"
          ++ lib.optional (cfg.seedAccountsFile != null) "seed-accounts:${cfg.seedAccountsFile}";

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
      // lib.optionalAttrs (cfg.extraEnvironment != { }) {
        environment = cfg.extraEnvironment;
      }
      // lib.optionalAttrs useStateDirectory {
        StateDirectory = [ (builtins.baseNameOf stateDir) ];
      }
      // lib.optionalAttrs (!useStateDirectory) {
        ReadWritePaths = [ stateDir ];
      };
    };

    system.activationScripts.xiaohuanxiong2api = lib.stringAfter [ "users" ] ''
      install -d -m 0700 ${lib.escapeShellArg stateDir}
      chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg stateDir}
    '';

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
