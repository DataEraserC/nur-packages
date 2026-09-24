{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.mimocode2api;

  inherit (cfg) stateDir;

  # systemd can only create the state directory when it lives directly below
  # /var/lib; anything else has to exist already (ProtectSystem=strict makes
  # ReadWritePaths fail on a missing path).
  useStateDirectory = builtins.dirOf stateDir == "/var/lib";

  # The server generates its client id on first start and reuses it from then
  # on, so the file has to live in the writable state directory instead of the
  # default path relative to the working directory.
  clientFilePath = "${stateDir}/client";

  # Keep the evaluation alive when the package is missing so that the
  # assertions below can report it instead of lib.getExe crashing.
  serverExecutable =
    if cfg.package != null then lib.getExe cfg.package else "${pkgs.coreutils}/bin/false";
in
{
  options.services.dataEraserc.mimocode2api = {
    enable = lib.mkEnableOption "mimocode2api gateway";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.mimocode2api or null;
      description = ''
        mimocode2api server package. Defaults to `pkgs.mimocode2api`, which is
        the repository version when the NUR overlay is applied.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "TCP port the gateway listens on (also used by `openFirewall`).";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "mimo-auto";
      description = ''
        Default model alias forwarded upstream when a request does not select
        one explicitly.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/mimocode2api";
      description = ''
        Writable state directory holding the persisted client id. Directories
        outside <filename>/var/lib</filename> have to exist beforehand.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "mimocode2api";
      description = ''
        User account under which the service runs. When changed from the
        default the account has to be defined elsewhere.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "mimocode2api";
      description = ''
        Group under which the service runs. When changed from the default the
        group has to be defined elsewhere.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to open the configured port in the firewall. The upstream
        server always binds all interfaces, so leaving this disabled keeps the
        gateway reachable from the local machine only unless another rule
        exposes it. The API is served over plain HTTP, so expose it to the
        network only behind a TLS terminating reverse proxy.
      '';
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        {
          RUST_LOG = "info,mimocode2api=debug";
        }
      '';
      description = "Extra environment variables for the service.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/mimocode2api.env";
      description = "Environment file as defined in {manpage}`systemd.exec(5)`.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.dataEraserc.mimocode2api.package must be set when the service is enabled.";
      }
      {
        assertion = cfg.user == "mimocode2api" || builtins.hasAttr cfg.user config.users.users;
        message = ''
          services.dataEraserc.mimocode2api.user is set to "${cfg.user}", but that user is not
          defined. Keep the default to have the module create it, or define
          users.users."${cfg.user}".
        '';
      }
      {
        assertion = cfg.group == "mimocode2api" || builtins.hasAttr cfg.group config.users.groups;
        message = ''
          services.dataEraserc.mimocode2api.group is set to "${cfg.group}", but that group is not
          defined. Keep the default to have the module create it, or define
          users.groups."${cfg.group}".
        '';
      }
    ];

    users.users = lib.mkIf (cfg.user == "mimocode2api") {
      mimocode2api = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "mimocode2api service user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "mimocode2api") {
      mimocode2api = { };
    };

    systemd.services.mimocode2api = {
      description = "Xiaomi MiMo Code free models to OpenAI compatible API gateway";
      documentation = [ "https://github.com/wx8472235-cell/mimocode2api" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        MIMOCODE_PORT = toString cfg.port;
        MIMOCODE_CLIENT_FILE = clientFilePath;
        MIMOCODE_MODEL = cfg.model;
      }
      // cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = serverExecutable;
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectoryMode = "0700";
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
      }
      // lib.optionalAttrs (!useStateDirectory) {
        ReadWritePaths = [ stateDir ];
      };
    };

    system.activationScripts.mimocode2api = lib.stringAfter [ "users" ] ''
      install -d -m 0700 ${lib.escapeShellArg stateDir}
      chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg stateDir}
    '';

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
