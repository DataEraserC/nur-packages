{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dataEraserc.hkdm;
in
{
  options.services.dataEraserc.hkdm = {
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
      description = "The package to use for the Hotkey Daemon. Must be specified if `services.dataEraserc.hkdm.enable` is true. Example: `nur-repo.packages.${pkgs.system}.hkdm`";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.configFile != null;
        message = "The option `services.dataEraserc.hkdm.configFile` must be set when `services.dataEraserc.hkdm.enable` is true.";
      }
      {
        assertion = cfg.package != null;
        message = "The option `services.dataEraserc.hkdm.package` must be set when `services.dataEraserc.hkdm.enable` is true.";
      }
    ];

    systemd.services.hkdm = {
      description = "Hotkey Daemon (For) Mobile";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        ExecStart = "${lib.getExe cfg.package} -i -c ${cfg.configFile}";
      };
    };
  };
}
