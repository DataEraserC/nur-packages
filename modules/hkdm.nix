{
  config,
  lib,
  ...
}:
{
  options.services.hkdm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Hotkey Daemon for mobile devices";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = ''
        Path to the hkdm configuration file. Example: `''${ttyescape}/etc/hkdm/config.d/ttyescape.toml`.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = null;
      description = "The package to use for the Hotkey Daemon. Must be specified if `services.hkdm.enable` is true.";
    };
  };

  config = lib.mkIf config.services.hkdm.enable {
    assertions = [
      {
        assertion = config.services.hkdm.configFile != null;
        message = "The option `services.hkdm.configFile` must be set when `services.hkdm.enable` is true.";
      }
      {
        assertion = config.services.hkdm.package != null;
        message = "The option `services.hkdm.package` must be set when `services.hkdm.enable` is true.";
      }
    ];

    systemd.services.hkdm = {
      description = "Hotkey Daemon (For) Mobile";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        ExecStart = "${config.services.hkdm.package}/bin/hkdm -i -c ${config.services.hkdm.configFile}";
      };
    };
  };
}
