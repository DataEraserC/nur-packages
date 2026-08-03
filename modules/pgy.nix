{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.pgy;
  pkg = cfg.package.override {
    dataDir = cfg.stateDir;
    configFile = cfg.configFile;
  };
in
{
  options.services.pgy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Oray PgyVisitor software-defined networking client daemon (pgyvpn_svr) in an FHS sandbox.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = null;
      description = ''
        The pgy package (FHS wrapper) to use. Must be set if `services.pgy.enable` is true.
        Example: `nur-repo.packages."$PACKAGE_SYSTEM".pgy_fhs`
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pgyvpn";
      description = "Writable data directory bound read-write into the sandbox as `/etc/oray/pgyvpn` (status/login state).";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr (lib.types.oneOf [
        lib.types.pathInStore
        lib.types.externalPath
      ]);
      default = pkgs.writeText "pgyvpn-config.ini" ''
        ;local configuration
        [base]

        ;Set whether to enforce certificate validation
        ;certcheck=true

        ;Set whether to use smart bypass
        ;smartbypass=true

        ;Specify the port used by P2P
        ;p2pport=0

        p2pport=0

        [account]

        ;Automatic Login
        ;autologin=true

        autologin=true
      '';
      description = ''
        Config file mounted into the sandbox as `/etc/oray/pgyvpn/config.ini`.

        - A path in the Nix store (e.g. from `pkgs.writeText`) is bound read-write but
          stays read-only because the store is immutable.
        - An absolute path outside the store (e.g. `/etc/pgy/config.ini` or an
          out-of-store symlink target) is bound read-write and changes made by the
          daemon are synced back to that file.

        Defaults to the packaged default config (a read-only store file).

        Requires nixos-unstable / 26.05+ because `lib.types.externalPath` was added
        in nixpkgs 26.05; building this module against older branches (e.g. 24.11)
        fails with a missing attribute.
      '';
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/oray";
      description = "Directory to store pgyvpn_svr logs.";
    };

    apiAddress = lib.mkOption {
      type = lib.types.str;
      default = "pgy-api.oray.com";
      description = "The Oray web API address to connect to.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments appended to the `pgyvpn_svr` command line.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "The option `services.pgy.package` must be set when `services.pgy.enable` is true.";
      }
    ];

    systemd.services.pgyvpn = {
      description = "Oray PgyVisitor software-defined networking client daemon";
      after = [ "network.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart =
          [ "${pkg}/bin/pgy" "pgyvpn_svr" ]
          ++ [
            "-R"
            "-A"
            "--mlink"
            "-t"
            "-i"
            cfg.apiAddress
            "-K"
            "255.255.255.255"
            "-p"
            "${cfg.logDir}/pgyvpn_svr"
            "-f"
            "/etc/oray/pgyvpn/config.ini"
            "--logmask"
            "0xFFFFFFF7"
            "--norpceventnotify"
          ]
          ++ cfg.extraArgs;
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };

    environment.systemPackages = [ pkg ];

    system.activationScripts.pgy = lib.stringAfter [ "system" ] ''
      mkdir -p ${cfg.logDir}
      mkdir -p ${cfg.stateDir}
    '';
  };
}