{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.services.hkdm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Hotkey Daemon for mobile devices";
    };
  };

  config = lib.mkIf config.services.hkdm.enable {
    systemd.services.hkdm = {
      description = "Hotkey Daemon (For) Mobile";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        ExecStart = "${pkgs.hkdm}/bin/hkdm";
      };
    };
  };
}
