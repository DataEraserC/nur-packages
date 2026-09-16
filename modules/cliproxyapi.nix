{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.services.dataEraserc.cliproxyapi;
  format = pkgs.formats.yaml { };

  inherit (cfg) stateDir;
  authDir = if cfg.authDir != null then cfg.authDir else stateDir;
  configPath = "${stateDir}/config.yaml";
  keyFile =
    if cfg.managementKeyFile != null then cfg.managementKeyFile else "${stateDir}/management.key";

  # systemd creates and owns directories directly below /var/lib. Every other
  # writable path has to exist up front, because ProtectSystem=strict makes the
  # unit fail when a ReadWritePaths entry is missing.
  writableDirs = lib.unique [
    stateDir
    authDir
  ];
  stateDirectories = map builtins.baseNameOf (
    lib.filter (dir: builtins.dirOf dir == "/var/lib") writableDirs
  );
  readWritePaths = lib.filter (dir: builtins.dirOf dir != "/var/lib") writableDirs;

  usePanel = cfg.managementCenterPackage != null && !cfg.disableControlPanel;

  panelDir = pkgs.runCommand "cliproxyapi-management-panel" { } ''
    mkdir -p $out
    if [ -e ${cfg.managementCenterPackage}/management.html ]; then
      ln -s ${cfg.managementCenterPackage}/management.html $out/management.html
    elif [ -e ${cfg.managementCenterPackage}/index.html ]; then
      ln -s ${cfg.managementCenterPackage}/index.html $out/management.html
    else
      echo "cliproxyapi: the panel package provides neither management.html nor index.html" >&2
      exit 1
    fi
  '';

  configuredSecretKey = lib.attrByPath [ "remote-management" "secret-key" ] null cfg.settings;
  userKeySet = configuredSecretKey != null;
  plaintextSecretKey = builtins.isString configuredSecretKey;

  remoteManagement = {
    "allow-remote" = cfg.allowRemote;
  }
  // lib.optionalAttrs usePanel {
    "disable-auto-update-panel" = true;
  }
  // lib.optionalAttrs cfg.disableControlPanel {
    "disable-control-panel" = true;
  }
  // lib.optionalAttrs (!userKeySet) {
    "secret-key"."_secret" = keyFile;
  };

  settings = lib.recursiveUpdate {
    inherit (cfg) host port;
    "auth-dir" = authDir;
    "remote-management" = remoteManagement;
  } cfg.settings;

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

  # config.yaml embeds the resolved secret values and is seeded only once so that
  # management panel edits survive restarts. A rotated secret therefore has to
  # invalidate the seeded file explicitly, while a changed `settings` value can
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
            rm -f ${lib.escapeShellArg configPath}
          elif [ "$current_settings" != "$old_settings" ]; then
            echo "cliproxyapi: ${configPath} was seeded by an earlier configuration and keeps winning; delete it or set mutableConfig = false to apply the current settings" >&2
          fi
        fi

        rm -f "$marker"
        printf '%s %s\n' "$current_secrets" "$current_settings" > "$marker"
        chmod 0600 "$marker"

        if [ ! -e ${lib.escapeShellArg configPath} ]; then
          ${secretsReplacement.script}
        fi
      ''
    else
      secretsReplacement.script;

  # Keep the evaluation alive when the package is missing, so that the assertion
  # below reports it instead of lib.getExe crashing.
  serverExecutable =
    if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false";

  startCommand =
    "${serverExecutable} -config ${lib.escapeShellArg configPath}"
    + lib.optionalString cfg.localModel " -local-model"
    + lib.optionalString (cfg.extraArgs != [ ]) (" " + lib.escapeShellArgs cfg.extraArgs);
in
{
  disabledModules = [ "services/misc/cliproxyapi.nix" ];

  options.services.dataEraserc.cliproxyapi = {
    enable = lib.mkEnableOption "CLIProxyAPI";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.cliproxyapi or null;
      description = ''
        CLIProxyAPI server package (`bin/server`). Defaults to `pkgs.cliproxyapi`,
        which is the repository version when the NUR overlay is applied.
      '';
    };

    managementCenterPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.cliproxyapi-management-center or null;
      description = ''
        Package providing the offline management WebUI, either as
        `management.html` or as `index.html`. When set, the server serves it
        through `MANAGEMENT_STATIC_PATH` and GitHub panel updates are disabled.
        When null, the server downloads the panel itself.

        `pkgs.cliproxyapi-management-center-bin` ships the same panel straight from
        the upstream release asset and avoids an npm build.
      '';
    };

    disableControlPanel = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Disable the bundled `/management.html` route entirely. Use this when the
        panel is hosted externally (for example by nginx).
      '';
    };

    settings = lib.mkOption {
      inherit (format) type;
      default = { };
      example = lib.literalExpression ''
        {
          api-keys = [ { _secret = "/run/secrets/cliproxyapi-api-key"; } ];
        }
      '';
      description = ''
        CLIProxyAPI configuration, merged on top of the module defaults. Keys use
        the upstream kebab-case names. Secret values can be loaded from files with
        `._secret = "/path/to/secret";`; plaintext values end up in the Nix store
        through the config generation script.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/cliproxyapi";
      description = ''
        Writable state directory holding the generated config, auth files and the
        management key. Directories directly below `/var/lib` are created by
        systemd, any other path has to exist before the service starts.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "cliproxyapi";
      description = ''
        User account under which CLIProxyAPI runs. The account is created when the
        default is kept; otherwise it has to be defined elsewhere.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "cliproxyapi";
      description = ''
        Group under which CLIProxyAPI runs. The group is created when the default
        is kept; otherwise it has to be defined elsewhere.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address the server binds to. Defaults to localhost; set to `0.0.0.0` to
        expose the proxy and management API on the network.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8317;
      description = "Server port (also used by `openFirewall`; `settings.port` takes precedence).";
    };

    authDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Directory holding the provider credentials. Defaults to `stateDir`; a
        different path is added to the writable paths of the service.
      '';
    };

    managementKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        File containing the management key, wired into
        `remote-management.secret-key._secret`. When null, a random key is created
        at `''${stateDir}/management.key` on first activation.

        Rotating the file invalidates a previously seeded `config.yaml`, so the new
        key takes effect on the next start.
      '';
    };

    allowRemote = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Value of `remote-management.allow-remote` in the generated config. Every
        management API request needs a valid management key, but clients that do
        not connect from `127.0.0.1`/`::1` are rejected unless this is enabled,
        which also covers a browser reaching the panel over a forwarded port.
      '';
    };

    mutableConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true (default), `config.yaml` is only generated when missing, so
        changes made through the management panel/API persist across restarts.
        Rotating a secret regenerates the file; changing `settings` only logs a
        warning. When false, the config is regenerated from `settings` on every
        start.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/cliproxyapi.env";
      description = "Environment file as defined in {manpage}`systemd.exec(5)`.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for the configured port.";
    };

    localModel = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Pass `-local-model` to use embedded model catalogs and skip remote fetching.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments appended to the server command line.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the service.";
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.optional plaintextSecretKey ''
      services.dataEraserc.cliproxyapi.settings."remote-management"."secret-key" is a plaintext
      value that ends up in the Nix store. Use `secret-key._secret = "/path/to/key"` instead.
    '';

    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.dataEraserc.cliproxyapi.package must be set when the service is enabled.";
      }
      {
        assertion = lib.isInt (settings.port or cfg.port);
        message = "services.dataEraserc.cliproxyapi.settings.port must be an integer.";
      }
      {
        assertion = cfg.user == "cliproxyapi" || builtins.hasAttr cfg.user config.users.users;
        message = ''
          services.dataEraserc.cliproxyapi.user is set to "${cfg.user}", but that user is not
          defined. Keep the default to have the module create it, or define
          users.users."${cfg.user}".
        '';
      }
      {
        assertion = cfg.group == "cliproxyapi" || builtins.hasAttr cfg.group config.users.groups;
        message = ''
          services.dataEraserc.cliproxyapi.group is set to "${cfg.group}", but that group is not
          defined. Keep the default to have the module create it, or define
          users.groups."${cfg.group}".
        '';
      }
    ];

    users.users = lib.mkIf (cfg.user == "cliproxyapi") {
      cliproxyapi = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "CLIProxyAPI service user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "cliproxyapi") {
      cliproxyapi = { };
    };

    systemd.services.cliproxyapi = {
      description = "Proxy that provides OpenAI/Gemini/Claude/Codex/Grok compatible API interfaces";
      documentation = [ "https://github.com/router-for-me/CLIProxyAPI" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = seedConfig;

      environment =
        lib.optionalAttrs (!cfg.disableControlPanel) {
          MANAGEMENT_STATIC_PATH = if usePanel then "${panelDir}" else "${stateDir}/static";
        }
        // cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        StateDirectoryMode = "0700";
        WorkingDirectory = stateDir;
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
      // lib.optionalAttrs (stateDirectories != [ ]) {
        StateDirectory = stateDirectories;
      }
      // lib.optionalAttrs (readWritePaths != [ ]) {
        ReadWritePaths = readWritePaths;
      };
    };

    system.activationScripts.cliproxyapi = lib.stringAfter [ "users" ] ''
      install -d -m 0700 ${lib.escapeShellArg stateDir} ${lib.escapeShellArg authDir}
      chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg stateDir} ${lib.escapeShellArg authDir}

      ${lib.optionalString (cfg.managementKeyFile == null) ''
        if [ ! -e ${lib.escapeShellArg keyFile} ]; then
          (umask 077; ${lib.getExe pkgs.openssl} rand -base64 32 > ${lib.escapeShellArg keyFile})
          chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg keyFile}
        fi
        chmod 0600 ${lib.escapeShellArg keyFile}
      ''}
    '';

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ (settings.port or cfg.port) ];
    };
  };
}
