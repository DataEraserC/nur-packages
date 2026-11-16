{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.meoo2api;

  inherit (cfg) stateDir;

  # systemd can only create the state directory when it lives directly below
  # /var/lib; anything else has to exist already (ProtectSystem=strict makes
  # ReadWritePaths fail on a missing path).
  useStateDirectory = builtins.dirOf stateDir == "/var/lib";

  # Keep the evaluation alive when the package is missing so that the
  # assertions below can report it instead of lib.getExe crashing.
  serverExecutable =
    if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false";

  # Bootstrap credentials are only read while state.json does not exist yet;
  # later changes intentionally do not reset console-managed state. Reset the
  # administrator password by stopping the service and running
  # `meoo2api -data <stateDir> --reset-password`.
  startScript = pkgs.writeShellScript "meoo2api-start" ''
    set -eu
    ${lib.optionalString (cfg.adminPasswordFile != null) ''
      export MEOO2API_ADMIN_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/admin-password")"
    ''}
    ${lib.optionalString (cfg.projectAkFile != null) ''
      export MEOO_PROJECT_AK="$(cat "$CREDENTIALS_DIRECTORY/project-ak")"
    ''}
    ${lib.optionalString (cfg.clientKeysFile != null) ''
      export MEOO2API_KEYS="$(cat "$CREDENTIALS_DIRECTORY/client-keys")"
    ''}
    exec ${serverExecutable} -bind ${lib.escapeShellArg cfg.host} -port ${toString cfg.port} -data ${lib.escapeShellArg stateDir}
  '';
in
{
  options.services.dataEraserc.meoo2api = {
    enable = lib.mkEnableOption "meoo2api gateway";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.meoo2api or null;
      description = ''
        meoo2api server package. Defaults to `pkgs.meoo2api`, which is the
        repository version when the NUR overlay is applied.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "meoo2api";
      description = ''
        User account under which the service runs. When changed from the
        default the account has to be defined elsewhere.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "meoo2api";
      description = ''
        Group under which the service runs. When changed from the default the
        group has to be defined elsewhere.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/meoo2api";
      description = ''
        Writable state directory holding <filename>state.json</filename> and
        the directory lock. Directories outside <filename>/var/lib</filename>
        have to exist beforehand.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Address the server binds to. Defaults to localhost; set to
        `0.0.0.0` to expose the gateway and console on the network.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8791;
      description = "TCP port the gateway and console listen on.";
    };

    adminPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/meoo2api-admin-password";
      description = ''
        File containing the initial administrator password as plain text,
        loaded as a systemd credential and passed through
        <literal>MEOO2API_ADMIN_PASSWORD</literal>. It only seeds the password
        while <filename>state.json</filename> does not exist yet; a password
        changed in the console stays in effect, and rotating this file does
        not reset it.

        Without this option the server generates a random password on first
        start and prints it once to the journal
        (<command>journalctl -u meoo2api</command>). To reset an existing
        password, stop the service and run
        <command>meoo2api -data ${stateDir} --reset-password</command>.
      '';
    };

    projectAkFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/meoo2api-project-ak";
      description = ''
        File containing a project API key (<literal>meoo_project_…</literal>)
        used to preseed the account pool on first start, loaded as a systemd
        credential and passed through <literal>MEOO_PROJECT_AK</literal>.
        Ignored once <filename>state.json</filename> exists.
      '';
    };

    clientKeysFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/meoo2api-client-keys";
      description = ''
        File containing client API keys (<literal>sk-…</literal>) separated by
        commas, used to preseed the gateway on first start, loaded as a
        systemd credential and passed through
        <literal>MEOO2API_KEYS</literal>. Ignored once
        <filename>state.json</filename> exists.
      '';
    };

    meooAiBase = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://api.meoo.host/meoo-ai/compatible-mode/v1";
      description = ''
        Upstream Meoo gateway base URL, passed through
        <literal>MEOO_AI_BASE</literal>. <literal>null</literal> keeps the
        upstream default of
        <literal>https://api.meoo.host/meoo-ai/compatible-mode/v1</literal>.
      '';
    };

    timeZone = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Asia/Shanghai";
      description = ''
        Process time zone (<literal>TZ</literal>) used to compute the check-in
        date and hour. <literal>null</literal> keeps the system default.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to open the configured port in the firewall. The API and
        console are served over plain HTTP, so expose them to the network only
        behind a TLS terminating reverse proxy.
      '';
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        {
          MEOO_AI_BASE = "https://api.meoo.host/meoo-ai/compatible-mode/v1";
          MEOO2API_KEYS = "sk-one,sk-two";
          TZ = "Asia/Shanghai";
        }
      '';
      description = ''
        Extra environment variables for the service. Values placed here end up
        in the world-readable store, so keep secrets in
        <option>adminPasswordFile</option>, <option>projectAkFile</option>,
        <option>clientKeysFile</option> or <option>environmentFile</option>.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/meoo2api.env";
      description = "Environment file as defined in {manpage}`systemd.exec(5)`.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.dataEraserc.meoo2api.package must be set when the service is enabled.";
      }
      {
        assertion = cfg.user == "meoo2api" || builtins.hasAttr cfg.user config.users.users;
        message = ''
          services.dataEraserc.meoo2api.user is set to "${cfg.user}", but that user is not
          defined. Keep the default to have the module create it, or define
          users.users."${cfg.user}".
        '';
      }
      {
        assertion = cfg.group == "meoo2api" || builtins.hasAttr cfg.group config.users.groups;
        message = ''
          services.dataEraserc.meoo2api.group is set to "${cfg.group}", but that group is not
          defined. Keep the default to have the module create it, or define
          users.groups."${cfg.group}".
        '';
      }
    ];

    users.users = lib.mkIf (cfg.user == "meoo2api") {
      meoo2api = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "meoo2api service user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "meoo2api") {
      meoo2api = { };
    };

    systemd.services.meoo2api = {
      description = "Meoo model gateway with an OpenAI compatible API and account console";
      documentation = [ "https://github.com/LazyBonesLZY/meoo2api" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment =
        lib.optionalAttrs (cfg.meooAiBase != null) {
          MEOO_AI_BASE = cfg.meooAiBase;
        }
        // lib.optionalAttrs (cfg.timeZone != null) {
          TZ = cfg.timeZone;
        }
        // cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = startScript;
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectoryMode = "0700";
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
        LoadCredential =
          lib.optional (cfg.adminPasswordFile != null) "admin-password:${cfg.adminPasswordFile}"
          ++ lib.optional (cfg.projectAkFile != null) "project-ak:${cfg.projectAkFile}"
          ++ lib.optional (cfg.clientKeysFile != null) "client-keys:${cfg.clientKeysFile}";

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
      }
      // lib.optionalAttrs (!useStateDirectory) {
        ReadWritePaths = [ stateDir ];
      };
    };

    system.activationScripts.meoo2api = lib.stringAfter [ "users" ] ''
      install -d -m 0700 ${lib.escapeShellArg stateDir}
      chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg stateDir}
    '';

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
