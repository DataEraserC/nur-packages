{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.pgy;
  # The FHS wrapper takes the bind mounts as arguments; the native package
  # works directly against the host paths created by the activation script.
  isFhs = cfg.package != null && (cfg.package.passthru.fhs or false);
  fixedMachineCode = cfg.machineCode.fixedValue != null;
  # pgyvpn_svr derives its machine code from the first identifier source it
  # can read. A shim that answers the SMBIOS UUID query makes that source
  # deterministic without touching any NIC MAC.
  fakeDmidecode = pkgs.writeShellScriptBin "dmidecode" ''
    if [ "''${1:-}" = "-s" ] && [ "''${2:-}" = "system-uuid" ]; then
      echo ${lib.escapeShellArg cfg.machineCode.fixedValue}
      exit 0
    fi
    exit 1
  '';
  pkg =
    if cfg.package == null then
      null
    else if isFhs then
      cfg.package.override {
        dataDir = cfg.stateDir;
        inherit (cfg) configFile;
      }
    else
      cfg.package;
  defaultConfig = ''
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
in
{
  options.services.dataEraserc.pgy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Oray PgyVisitor software-defined networking client daemon (pgyvpn_svr).";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = null;
      description = ''
        The pgy package to use. Both the native package and the FHS wrapper are
        supported; the module detects the latter through its `passthru.fhs` marker.

        Example: `nur-repo.packages."$PACKAGE_SYSTEM".pgy`
        (or `...pgy-fhs` for the sandboxed variant)
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pgyvpn";
      description = ''
        Writable data directory for the daemon's status and login state.

        - With the FHS package it is bound read-write into the sandbox as
          `/etc/oray/pgyvpn`.
        - With the native package `/etc/oray/pgyvpn` is created as a symlink to
          this directory.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.oneOf [
          lib.types.pathInStore
          lib.types.externalPath
        ]
      );
      default = "${cfg.stateDir}/config.ini";
      description = ''
        Config file passed to the daemon as `/etc/oray/pgyvpn/config.ini`.

        - A path in the Nix store (e.g. from `pkgs.writeText`) is usable but
          stays read-only because the store is immutable.
        - An absolute path outside the store (e.g. `/etc/pgy/config.ini` or an
          out-of-store symlink target) is writable and changes made by the
          daemon (e.g. login state) are persisted there.

        Defaults to `${cfg.stateDir}/config.ini`. If the file does not exist
        yet, the activation script creates it with the default configuration so
        the daemon can persist login state into it. Set to `null` to keep the
        packaged read-only config (FHS package) or let the daemon create its own
        file (native package).

        Requires nixos-unstable / 26.05+ because `lib.types.externalPath` was added
        in nixpkgs 26.05; building this module against older branches (e.g. 24.11)
        fails with a missing attribute.
      '';
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/oray";
      description = "Directory to store pgyvpn_svr logs and the `pgyvpn` log subdirectory.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = ''
        User that the pgyvpn_svr daemon runs as. Defaults to root because the
        daemon typically needs root privileges to set up its virtual network
        interface. If a dedicated user is used, it must be able to write to
        `stateDir`, `logDir` and `configFile` (the activation script chowns them
        accordingly). The FHS package additionally requires unprivileged user
        namespaces for its bwrap sandbox.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Group that the pgyvpn_svr daemon runs as.";
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

    machineCode = {
      useDmidecode = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Put `dmidecode` on the service PATH. `pgyvpn_svr` then prefers the
          SMBIOS system UUID over the NIC MAC when deriving its machine code,
          which is usually stable across NIC replacements.

          The command only makes the DMI source available; firmware that does
          not expose SMBIOS still falls back to the next source, and a
          non-root `user` cannot read it. This changes the machine code, so the
          stored login token may need a fresh login.
          Applies to both the native and the FHS package.
        '';
      };

      usePciutils = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Put `pciutils` (lspci) on the service PATH so `pgyvpn_svr` can use
          PCI IDs as another fingerprint source. The resulting machine code has
          not been observed yet, so this is opt-in. Applies to both the native
          and the FHS package.
        '';
      };

      fixedValue = lib.mkOption {
        type = lib.types.nullOr lib.types.nonEmptyStr;
        default = null;
        example = "3f2504e0-4f89-41d3-9a0c-0305e82c3301";
        description = ''
          Install a `dmidecode` shim that answers `-s system-uuid` with this
          value. `pgyvpn_svr` then derives a deterministic machine code from it
          instead of the real SMBIOS UUID or the NIC MAC.

          Useful when the hardware fingerprint is unstable (Wi-Fi MAC
          randomization, VM cloning, WSL) or when several hosts should share
          one login token. The value is not a secret, but every host using the
          same value looks like the same device to the pgy server. Changing it
          invalidates the stored token. Takes precedence over `useDmidecode`.
          Applies to both the native and the FHS package.
        '';
      };

      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = ''
          Additional packages to put on the service PATH. Use this when a new
          pgy version probes another command for its machine code, so the
          dependency can be supplied without changing this module.
          Applies to both the native and the FHS package.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "The option `services.dataEraserc.pgy.package` must be set when `services.dataEraserc.pgy.enable` is true.";
      }
    ];

    systemd.services.pgyvpn = {
      description = "Oray PgyVisitor software-defined networking client daemon";
      after = [ "network.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path =
        lib.optionals cfg.machineCode.usePciutils [ pkgs.pciutils ]
        ++ lib.optionals (cfg.machineCode.useDmidecode && !fixedMachineCode) [ pkgs.dmidecode ]
        ++ lib.optionals fixedMachineCode [ fakeDmidecode ]
        ++ cfg.machineCode.extraPackages;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = lib.escapeShellArgs (
          [
            "${pkg}/bin/pgy"
            "pgyvpn_svr"
          ]
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
          ++ cfg.extraArgs
        );
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };

    environment.systemPackages = [ pkg ];

    system.activationScripts.pgy = lib.stringAfter [ "specialfs" ] ''
      mkdir -p ${lib.escapeShellArg cfg.logDir}/pgyvpn
      mkdir -p ${lib.escapeShellArg cfg.stateDir}
      ${lib.optionalString (cfg.configFile != null) ''
        if [ ! -e ${lib.escapeShellArg cfg.configFile} ]; then
          mkdir -p "$(dirname ${lib.escapeShellArg cfg.configFile})"
          cat > ${lib.escapeShellArg cfg.configFile} <<'EOF'
        ${defaultConfig}
        EOF
        fi
        chown ${lib.escapeShellArg cfg.user}:${lib.escapeShellArg cfg.group} ${lib.escapeShellArg cfg.configFile} || true
      ''}
      chown -R ${lib.escapeShellArg cfg.user}:${lib.escapeShellArg cfg.group} ${lib.escapeShellArg cfg.stateDir} || true
      chown -R ${lib.escapeShellArg cfg.user}:${lib.escapeShellArg cfg.group} ${lib.escapeShellArg cfg.logDir}/pgyvpn || true
      ${lib.optionalString (!isFhs) ''
        # The native binaries still open these absolute paths at runtime.
        mkdir -p /etc/oray
        if [ ! -e /etc/oray/pgyvpn ] && [ ! -L /etc/oray/pgyvpn ]; then
          ln -s ${lib.escapeShellArg cfg.stateDir} /etc/oray/pgyvpn
        fi
        if [ ! -e /var/log/oray ] && [ ! -L /var/log/oray ]; then
          ln -s ${lib.escapeShellArg cfg.logDir} /var/log/oray
        fi
      ''}
    '';
  };
}
