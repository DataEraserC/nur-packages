{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.dataEraserc.browser4;
in
{
  options.programs.dataEraserc.browser4 = {
    enable = lib.mkEnableOption "browser4 browser automation CLI and backend";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.browser4 or null;
      description = ''
        browser4 package (wrapped CLI). Defaults to `pkgs.browser4`, which is
        the repository version when the NUR overlay is applied. The unwrapped
        build is available as `browser4-unwrapped`.
      '';
    };

    browserPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to the browser executable the browser4 backend drives, exported
        as `BROWSER4_BROWSER_PATH`. Leave null to keep the ambient browser
        detection of the CLI.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "programs.dataEraserc.browser4.package is null; set it to a browser4 package (the NUR overlay is not applied).";
      }
    ];

    environment.systemPackages = lib.optional (cfg.package != null) cfg.package;

    environment.sessionVariables = lib.optionalAttrs (cfg.browserPath != null) {
      BROWSER4_BROWSER_PATH = cfg.browserPath;
    };
  };
}
