{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.services.dataEraserc.opencode2api;
  format = pkgs.formats.json { };

  inherit (cfg) stateDir;

  # systemd creates and owns directories directly below /var/lib. Every other
  # writable path has to exist up front, because ProtectSystem=strict makes the
  # unit fail when a ReadWritePaths entry is missing.
  useStateDirectory = builtins.dirOf stateDir == "/var/lib";

  # The server rewrites this file in place (bootstrap password migration and
  # WebUI saves) and keeps its model caches beside it, so it has to live in the
  # writable state directory.
  configPath = "${stateDir}/config.json";

  # opencode2api rejects a configuration without a local API key. Unless
  # `settings.server_keys` provides one, a random key is generated here on first
  # activation and injected through a systemd credential.
  serverKeyPath = if cfg.serverKeyFile != null then cfg.serverKeyFile else "${stateDir}/server.key";
  generateServerKey = (cfg.settings.server_keys or [ ]) == [ ];

  defaultSettings = {
    listen = "${cfg.host}:${toString cfg.port}";
    server_keys = lib.optional generateServerKey { _secret = serverKeyPath; };
    webui = {
      enabled = cfg.webUi.enable;
      listen = "${cfg.webUi.host}:${toString cfg.webUi.port}";
      username = cfg.webUi.username;
      session_ttl_minutes = cfg.webUi.sessionTtlMinutes;
    }
    // lib.optionalAttrs (cfg.webUi.passwordFile != null) {
      password._secret = cfg.webUi.passwordFile;
    };
  };

  settings = lib.recursiveUpdate defaultSettings cfg.settings;

  webUiSettings = settings.webui or { };
  webUiEnabled = lib.isAttrs webUiSettings && (webUiSettings.enabled or false);

  # `settings` may already carry a bootstrap password or a migrated hash, in
  # which case `webUi.passwordFile` is not needed.
  settingsHavePassword =
    lib.isAttrs webUiSettings
    && ((webUiSettings.password or "") != "" || (webUiSettings.password_hash or "") != "");

  secretsReplacement = utils.genJqSecretsReplacement { loadCredential = true; } settings configPath;

  # The credential references stay literal so that bash expands
  # $CREDENTIALS_DIRECTORY at runtime. Their tags are sanitized by
  # genJqSecretsReplacement and are therefore safe to use unquoted.
  credentialFiles = map (
    entry: "$CREDENTIALS_DIRECTORY/" + lib.head (lib.splitString ":" entry)
  ) secretsReplacement.credentials;

  secretsSource =
    if credentialFiles == [ ] then
      "printf '%s' none"
    else
      "sha256sum ${lib.concatStringsSep " " credentialFiles}";

  settingsFingerprint = builtins.hashString "sha256" (builtins.toJSON settings);

  # config.json embeds the resolved secret values and is seeded only once so that
  # WebUI edits survive restarts. The server rewrites it on the first start to
  # replace the bootstrap password with its Argon2id hash, so a rotated secret
  # has to invalidate the seeded file explicitly. A changed `settings` value can
  # only be reported, because applying it would discard those edits.
  seedConfig =
    if cfg.mutableConfig then
      ''
        marker=${lib.escapeShellArg "${stateDir}/.config-fingerprint"}
        secrets_raw="$(${secretsSource} 2>/dev/null || true)"
        current_secrets="$(printf '%s' "$secrets_raw" | sha256sum | cut -d' ' -f1)"
        current_settings=${lib.escapeShellArg settingsFingerprint}

        if [ -r "$marker" ]; then
          old_secrets=""
          old_settings=""
          read -r old_secrets old_settings < "$marker" || true
          if [ "$current_secrets" != "$old_secrets" ]; then
            rm -f ${lib.escapeShellArg configPath} ${lib.escapeShellArg "${configPath}.bak"}
          elif [ "$current_settings" != "$old_settings" ]; then
            echo "opencode2api: ${configPath} was seeded by an earlier configuration and keeps winning; delete it or set mutableConfig = false to apply the current settings" >&2
          fi
        fi

        # Seed first and record the fingerprint only afterwards: a failed seed
        # (jq error, missing credential) leaves a zero-length file that is
        # retried instead of being recorded as the seeded configuration.
        if [ ! -s ${lib.escapeShellArg configPath} ]; then
          ${secretsReplacement.script}
        fi

        rm -f "$marker"
        printf '%s %s\n' "$current_secrets" "$current_settings" > "$marker"
        chmod 0600 "$marker"
      ''
    else
      secretsReplacement.script;

  # Keep the evaluation alive when the package is missing, so that the assertion
  # below reports it instead of lib.getExe crashing.
  serverExecutable =
    if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false";

  startCommand =
    "${serverExecutable} -config ${lib.escapeShellArg configPath}"
    + lib.optionalString (cfg.extraArgs != [ ]) (" " + lib.escapeShellArgs cfg.extraArgs);

  # Both listeners are configured as "host:port" strings and may be overridden
  # through `settings`, so the firewall rule parses the effective values.
  portOf =
    listen:
    let
      match = builtins.match ".*:([0-9]+)" listen;
    in
    if match == null then null else lib.toInt (builtins.head match);

  apiPort = portOf (settings.listen or "");
  webUiPort = if webUiEnabled then portOf (webUiSettings.listen or "") else null;
  firewallPorts = lib.unique (
    lib.filter (port: port != null) [
      apiPort
      webUiPort
    ]
  );
in
{
  options.services.dataEraserc.opencode2api = {
    enable = lib.mkEnableOption "opencode2api gateway";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.opencode2api or null;
      description = ''
        opencode2api server package. Defaults to `pkgs.opencode2api`, which is
        the repository version when the NUR overlay is applied.
      '';
    };

    settings = lib.mkOption {
      inherit (format) type;
      default = { };
      example = lib.literalExpression ''
        {
          anonymous = true;
          zen_keys = [ { _secret = "/run/secrets/opencode2api-zen-key"; } ];
        }
      '';
      description = ''
        opencode2api configuration, merged on top of the module defaults. Keys
        use the upstream snake_case names. Secret values can be loaded from
        files with `._secret = "/path/to/secret";`, which also works inside
        lists such as `server_keys`; plaintext values end up in the Nix store
        through the config generation script.

        `listen` and `webui.listen` default to the `host`/`port` and
        `webUi.host`/`webUi.port` options. At least one upstream key in
        `zen_keys` or `go_keys` is required unless `anonymous` is enabled.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/opencode2api";
      description = ''
        Writable state directory holding `config.json`, its model caches and the
        generated local API key. Directories directly below
        <filename>/var/lib</filename> are created by systemd, any other path has
        to exist before the service starts.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "opencode2api";
      description = ''
        User account under which the service runs. The account is created when
        the default is kept; otherwise it has to be defined elsewhere.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "opencode2api";
      description = ''
        Group under which the service runs. The group is created when the
        default is kept; otherwise it has to be defined elsewhere.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address the API listener binds to. Defaults to localhost; set to
        `0.0.0.0` to expose the gateway on the network.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "API port (also used by `openFirewall`; `settings.listen` takes precedence).";
    };

    serverKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/opencode2api-server-key";
      description = ''
        File containing the local API key clients authenticate with, wired into
        `server_keys`. When null, a random key is created at
        `''${stateDir}/server.key` on first activation; read it with
        `cat ''${stateDir}/server.key`.

        Rotating the file invalidates a previously seeded `config.json`, so the
        new key takes effect on the next start. Ignored when
        `settings.server_keys` is not empty.
      '';
    };

    webUi = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Serve the management WebUI on its own listener. Changes to the WebUI
          password or listener need a service restart.
        '';
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = ''
          Address the management listener binds to. The WebUI is served over
          plain HTTP, so expose it to the network only behind a TLS terminating
          reverse proxy.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8081;
        description = "Management port (also used by `openFirewall`; `settings.webui.listen` takes precedence).";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Administrator account name of the WebUI.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/run/secrets/opencode2api-webui-password";
        description = ''
          File containing the WebUI bootstrap password (at least 10 characters)
          as plain text, loaded as a systemd credential. On first start the
          server replaces it with an Argon2id hash inside `config.json` and
          deletes the plaintext backup.

          Rotating the file invalidates a previously seeded `config.json`, so the
          new password takes effect on the next start. Required unless
          `settings.webui` already carries `password` or `password_hash`.
        '';
      };

      sessionTtlMinutes = lib.mkOption {
        type = lib.types.ints.positive;
        default = 720;
        description = "Lifetime of a WebUI login session in minutes (5 to 10080).";
      };
    };

    mutableConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true (default), `config.json` is only generated when missing, so
        changes made through the WebUI persist across restarts. Rotating a
        secret regenerates the file; changing `settings` only logs a warning.
        When false, the config is regenerated from `settings` on every start.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the API and WebUI ports in the firewall.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments appended to the server command line (`-listen`, `-web-listen`).";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/opencode2api.env";
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
        message = "services.dataEraserc.opencode2api.package must be set when the service is enabled.";
      }
      {
        assertion = cfg.user == "opencode2api" || builtins.hasAttr cfg.user config.users.users;
        message = ''
          services.dataEraserc.opencode2api.user is set to "${cfg.user}", but that user is not
          defined. Keep the default to have the module create it, or define
          users.users."${cfg.user}".
        '';
      }
      {
        assertion = cfg.group == "opencode2api" || builtins.hasAttr cfg.group config.users.groups;
        message = ''
          services.dataEraserc.opencode2api.group is set to "${cfg.group}", but that group is not
          defined. Keep the default to have the module create it, or define
          users.groups."${cfg.group}".
        '';
      }
      {
        assertion = !webUiEnabled || cfg.webUi.passwordFile != null || settingsHavePassword;
        message = ''
          services.dataEraserc.opencode2api.webUi.enable requires a bootstrap password:
          set services.dataEraserc.opencode2api.webUi.passwordFile to a file holding
          at least 10 characters.
        '';
      }
      {
        assertion = !cfg.openFirewall || (apiPort != null && (!webUiEnabled || webUiPort != null));
        message = ''
          services.dataEraserc.opencode2api.openFirewall requires `listen` (and
          `webui.listen` when the WebUI is enabled) to be a host:port string with a
          numeric TCP port; parsing the effective settings failed.
        '';
      }
    ];

    users.users = lib.mkIf (cfg.user == "opencode2api") {
      opencode2api = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "opencode2api service user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "opencode2api") {
      opencode2api = { };
    };

    systemd.services.opencode2api = {
      description = "OpenCode Zen and Zen Go gateway with OpenAI and Anthropic compatible APIs";
      documentation = [ "https://github.com/jasonxu114514/opencode2api" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = seedConfig;

      environment = cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = startCommand;
        Restart = "on-failure";
        RestartSec = 5;
        LoadCredential = secretsReplacement.credentials;
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];

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
        StateDirectory = [ (builtins.baseNameOf stateDir) ];
        StateDirectoryMode = "0700";
      }
      // lib.optionalAttrs (!useStateDirectory) {
        ReadWritePaths = [ stateDir ];
      };
    };

    system.activationScripts.opencode2api = lib.stringAfter [ "users" ] ''
      install -d -m 0700 ${lib.escapeShellArg stateDir}
      chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg stateDir}

      ${lib.optionalString (generateServerKey && cfg.serverKeyFile == null) ''
        if [ ! -e ${lib.escapeShellArg serverKeyPath} ]; then
          (umask 077; ${lib.getExe pkgs.openssl} rand -base64 32 > ${lib.escapeShellArg serverKeyPath})
        fi
        chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg serverKeyPath}
        chmod 0600 ${lib.escapeShellArg serverKeyPath}
      ''}
    '';

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = firewallPorts;
    };
  };
}
