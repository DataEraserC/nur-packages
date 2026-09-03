{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cpolar;
in
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
      default = null;
      description = "The cpolar package to use. Must be specified if `services.cpolar.enable` is true. Example: `nur-repo.packages.${pkgs.system}.cpolar`";
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/cpolar";
      description = "Directory to store cpolar logs.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.configFile != null;
        message = "The option `services.cpolar.configFile` must be set when `services.cpolar.enable` is true.";
      }
      {
        assertion = cfg.package != null;
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
          ${lib.getExe cfg.package} start-all -daemon=on -dashboard=on -log=${cfg.logDir}/cpolar_service.log -config=${cfg.configFile}
        '';
        Restart = "on-failure";
        RestartSec = "5s";
        User = "cpolar";
        Group = "cpolar";
      };
    };

    environment.systemPackages = [ cfg.package ];

    system.activationScripts.cpolarLogDir = ''
      mkdir -p ${cfg.logDir}
      chown cpolar:cpolar ${cfg.logDir}
    '';

    system.activationScripts.cpolarConfigFile = ''
      chown cpolar:cpolar ${cfg.configFile}
    '';
  };
}
