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

    package = lib.mkPackageOption pkgs "cpolar" { };

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

    users.users.cpolar = {
      isSystemUser = true;
      group = "cpolar";
      description = "cpolar service user";
    };

    users.groups.cpolar = { };

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
        User = "cpolar";
        Group = "cpolar";
      };
    };

    environment.systemPackages = [ config.services.cpolar.package ];

    system.activationScripts.cpolarLogDir = ''
      mkdir -p ${config.services.cpolar.logDir}
      chown cpolar:cpolar ${config.services.cpolar.logDir}
    '';

    system.activationScripts.cpolarConfigFile = ''
      chown cpolar:cpolar ${config.services.cpolar.configFile}
    '';
  };
}
