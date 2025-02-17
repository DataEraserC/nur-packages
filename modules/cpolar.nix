{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.services.cpolar = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable cpolar secure tunnels to localhost webhook development tool and debugging tool.";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = ''
        Path to the cpolar configuration file. Example: `/etc/cpolar/cpolar.yml`.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.cpolar;
      description = "The cpolar package to use. Must be specified if `services.cpolar.enable` is true.";
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/cpolar";
      description = "Directory to store cpolar logs.";
    };
  };

  config = lib.mkIf config.services.cpolar.enable {
    assertions = [
      {
        assertion = config.services.cpolar.configFile != null;
        message = "The option `services.cpolar.configFile` must be set when `services.cpolar.enable` is true.";
      }
      {
        assertion = config.services.cpolar.package != null;
        message = "The option `services.cpolar.package` must be set when `services.cpolar.enable` is true.";
      }
    ];

    systemd.services.cpolar = {
      description = "cpolar secure tunnels to localhost webhook development tool and debugging tool.";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = ''
          ${lib.getExe config.services.cpolar.package} start-all -daemon=on -dashboard=on -log=${config.services.cpolar.logDir}/cpolar_service.log -config=${config.services.cpolar.configFile}
        '';
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    environment.systemPackages = [ config.services.cpolar.package ];

    system.activationScripts.cpolarLogDir = ''
      mkdir -p ${config.services.cpolar.logDir}
      chown cpolar:cpolar ${config.services.cpolar.logDir}
    '';
  };
}
