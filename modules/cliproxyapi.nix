{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.services.cliproxyapiCustom;
  format = pkgs.formats.yaml { };

  inherit (cfg) stateDir;
  configPath = "${stateDir}/config.yaml";
  authDir = if cfg.authDir != null then cfg.authDir else stateDir;

  keyFile =
    if cfg.managementKeyFile != null then cfg.managementKeyFile else "${stateDir}/management.key";

  useOfflinePanel = cfg.managementCenterPackage != null && !cfg.disableControlPanel;

  panelDir = pkgs.runCommand "cliproxyapi-management-panel" { } ''
    mkdir -p $out
    if [ -e ${cfg.managementCenterPackage}/management.html ]; then
      ln -s ${cfg.managementCenterPackage}/management.html $out/management.html
    else
      ln -s ${cfg.managementCenterPackage}/index.html $out/management.html
    fi
  '';

  userKeySet = lib.attrByPath [ "remote-management" "secret-key" ] null cfg.settings != null;

  remoteManagement = {
    "allow-remote" = cfg.allowRemote;
  }
  // lib.optionalAttrs useOfflinePanel {
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

  effectivePort = settings.port or cfg.port;

  startCommand =
    "${lib.getExe cfg.package} -config ${configPath}"
    + lib.optionalString cfg.localModel " -local-model"
    + lib.optionalString (cfg.extraArgs != [ ]) (" " + lib.escapeShellArgs cfg.extraArgs);
in
{
  disabledModules = [ "services/misc/cliproxyapi.nix" ];

  options.services.cliproxyapiCustom = {
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
        Package providing the offline management WebUI (a single-file
        `index.html`, optionally `management.html`). When set, the server serves it
        through `MANAGEMENT_STATIC_PATH` and GitHub panel updates are disabled.
        When null, the server downloads the panel itself.
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
        `._secret = "/path/to/secret";`.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/cliproxyapi";
      description = "Writable state directory (generated config, auth files and management key).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "cliproxyapi";
      description = "User account under which CLIProxyAPI runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "cliproxyapi";
      description = "Group under which CLIProxyAPI runs.";
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
      description = "Authentication/credential directory. Defaults to `stateDir`.";
    };

    managementKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        File containing the management key, wired into
        `remote-management.secret-key._secret`. When null, a random key is created
        at `''${stateDir}/management.key` on first activation.
      '';
    };

    allowRemote = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Value of `remote-management.allow-remote` in the generated config.";
    };

    mutableConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true (default), `config.yaml` is only generated when missing, so
        changes made through the management panel/API persist across restarts.
        When false, the config is regenerated from `settings` on every start.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
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
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.cliproxyapi.package must be set when services.cliproxyapi.enable is true.";
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

      preStart =
        if cfg.mutableConfig then
          ''
            if [ ! -e ${configPath} ]; then
              ${secretsReplacement.script}
            fi
          ''
        else
          secretsReplacement.script;

      environment =
        lib.optionalAttrs (!cfg.disableControlPanel) {
          MANAGEMENT_STATIC_PATH = if useOfflinePanel then "${panelDir}" else "${stateDir}/static";
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
      // lib.optionalAttrs (stateDir == "/var/lib/cliproxyapi") {
        StateDirectory = "cliproxyapi";
      }
      // {
        ReadWritePaths = [ stateDir ];
      };
    };

    system.activationScripts.cliproxyapi = lib.stringAfter [ "users" ] ''
      install -d -m 0700 ${lib.escapeShellArg stateDir} ${lib.escapeShellArg authDir}
      chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg stateDir} ${lib.escapeShellArg authDir}

      ${lib.optionalString (cfg.managementKeyFile == null) ''
        if [ ! -e ${lib.escapeShellArg keyFile} ]; then
          umask 077
          ${lib.getExe pkgs.openssl} rand -base64 32 > ${lib.escapeShellArg keyFile}
          chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg keyFile}
        fi
        chmod 0600 ${lib.escapeShellArg keyFile}
      ''}
    '';

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ effectivePort ];
    };
  };
}
