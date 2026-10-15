{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc."9router";

  inherit (cfg) stateDir;

  # systemd creates and owns directories directly below /var/lib. Every other
  # writable path has to exist up front, because ProtectSystem=strict makes the
  # unit fail when a ReadWritePaths entry is missing.
  useStateDirectory = builtins.dirOf stateDir == "/var/lib";

  # Keep the evaluation alive when the package is missing so that the
  # assertions below can report it instead of a string coercion error.
  packageRoot = if cfg.package != null then cfg.package else pkgs.coreutils;

  # npm installs the payload under the registry name from package.json, which
  # does not follow pname.
  appDir = "${packageRoot}/lib/node_modules/9router/app";

  # The CLI launcher (bin/9router) is deliberately bypassed. With a
  # non-interactive stdin it always enters tray mode, spawns the server as a
  # detached child, tries to install and start systray2, and before every start
  # kills every process whose command line contains "next-server" plus whatever
  # currently holds the configured port. Running the standalone server directly
  # keeps the unit at one process with predictable signal handling.
  startScript = pkgs.writeShellScript "9router-start" ''
    set -eu
    ${lib.optionalString (cfg.initialPasswordFile != null) ''
      if [ -s "$CREDENTIALS_DIRECTORY/initial-password" ]; then
        INITIAL_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/initial-password")"
        export INITIAL_PASSWORD
      fi
    ''}
    if [ -e ${appDir}/custom-server.js ]; then
      exec ${lib.getExe cfg.nodePackage} --dns-result-order=ipv4first ${appDir}/custom-server.js
    else
      exec ${lib.getExe cfg.nodePackage} --dns-result-order=ipv4first ${appDir}/server.js
    fi
  '';
in
{
  options.services.dataEraserc."9router" = {
    enable = lib.mkEnableOption "the 9Router local AI gateway";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs."9router" or (pkgs."_9router" or null);
      description = ''
        Gateway package to run. Defaults to <literal>pkgs.9router</literal>,
        which is this repository's version when the NUR overlay is applied, and
        falls back to the <literal>_9router</literal> package shipped by
        nixpkgs. Both install the same npm payload.
      '';
    };

    nodePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nodejs_24;
      example = lib.literalExpression "pkgs.nodejs_24";
      description = ''
        Node.js runtime the server is started with. It has to be at least 22.5
        so that the built-in <literal>node:sqlite</literal> driver exists: the
        published npm payload bundles neither a working
        <literal>better-sqlite3</literal> build nor the sql.js WebAssembly
        blob, so older runtimes end up with no usable database driver.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "9router";
      description = ''
        User account the service runs as. The default account is created
        automatically; any other name must already exist as a user.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "9router";
      description = ''
        Group the service runs as. The default group is created automatically;
        any other name must already exist as a group.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Address the gateway binds to, exported as the upstream
        <literal>HOSTNAME</literal> variable. The default keeps the dashboard
        and the API loopback-only; set <literal>0.0.0.0</literal> to listen on
        all interfaces, and set a dashboard password first, because the
        upstream default password is only accepted from the local machine.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 20128;
      description = "TCP port serving the 9Router dashboard and API.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/9router";
      description = ''
        Directory holding all mutable state (SQLite database, generated
        <filename>jwt-secret</filename>, logs), exported as the upstream
        <literal>DATA_DIR</literal> and <literal>HOME</literal> variables.
        Paths under <filename>/var/lib</filename> are created by systemd
        <literal>StateDirectory=</literal>; other locations are pre-created by
        a NixOS activation script and must stay writable by the service user.
      '';
    };

    initialPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/9router-initial-password";
      description = ''
        File containing the dashboard password as plain text, loaded as a
        systemd credential and exported as the upstream
        <literal>INITIAL_PASSWORD</literal> variable.

        Upstream consults that variable only while the database holds no
        password, so this seeds the first login and nothing else: once a
        password has been set from the dashboard, replacing the file has no
        effect. Without it the gateway accepts the upstream default password
        from the local machine only and demands a change before remote access.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/9router.env";
      description = ''
        Environment file as defined in {manpage}`systemd.exec(5)`, for secrets
        that should not be declared through <option>extraEnvironment</option>.
      '';
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        API_KEY_SECRET = "a-long-random-string";
      };
      description = ''
        Extra environment variables for the service, such as
        <literal>API_KEY_SECRET</literal> (salt for deriving API keys) or
        <literal>MACHINE_ID_SALT</literal>. They cannot override
        <literal>DATA_DIR</literal>, <literal>HOME</literal>,
        <literal>HOSTNAME</literal>, <literal>PORT</literal>,
        <literal>NODE_ENV</literal> or
        <literal>NEXT_TELEMETRY_DISABLED</literal>, which this module derives
        from its own options.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the configured service port in the firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "services.dataEraserc.\"9router\".package must not be null; set it to a 9router package (the NUR overlay is not applied and this nixpkgs provides no _9router).";
      }
      {
        assertion = cfg.user == "9router" || builtins.hasAttr cfg.user config.users.users;
        message = "services.dataEraserc.\"9router\".user must name an existing user when it differs from the default 9router account.";
      }
      {
        assertion = cfg.group == "9router" || builtins.hasAttr cfg.group config.users.groups;
        message = "services.dataEraserc.\"9router\".group must name an existing group when it differs from the default 9router group.";
      }
      {
        assertion = lib.versionAtLeast cfg.nodePackage.version "22.5";
        message = "services.dataEraserc.\"9router\".nodePackage must be Node.js 22.5 or newer for the built-in node:sqlite driver; the published payload has no working better-sqlite3 or sql.js fallback.";
      }
    ];

    users.users = lib.mkIf (cfg.user == "9router") {
      "9router" = {
        isSystemUser = true;
        inherit (cfg) group;
        home = stateDir;
        description = "9Router gateway service";
      };
    };

    users.groups = lib.mkIf (cfg.group == "9router") {
      "9router" = { };
    };

    systemd.services."9router" = {
      description = "9Router local AI gateway";
      documentation = [ "https://github.com/decolua/9router" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = cfg.extraEnvironment // {
        DATA_DIR = stateDir;
        HOME = stateDir;
        HOSTNAME = cfg.host;
        PORT = toString cfg.port;
        NODE_ENV = "production";
        NEXT_TELEMETRY_DISABLED = "1";
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = startScript;
        Restart = "on-failure";
        RestartSec = 5;
        # Next.js' start-server turns SIGTERM into process.exit(143), so a clean
        # systemctl stop is recorded as exit-code 143 instead of a signal.
        SuccessExitStatus = [ "143" ];
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
        LoadCredential = lib.optional (
          cfg.initialPasswordFile != null
        ) "initial-password:${cfg.initialPasswordFile}";

        # MemoryDenyWriteExecute is intentionally absent: V8 flips its JIT code
        # pages from r-x to rw during Isolate::Initialize and the process dies
        # immediately under that setting.
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

    system.activationScripts."9router" = lib.stringAfter [ "users" ] ''
      install -d -m 0700 ${lib.escapeShellArg stateDir}
      chown ${cfg.user}:${cfg.group} ${lib.escapeShellArg stateDir}
    '';

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
