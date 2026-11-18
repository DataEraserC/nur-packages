{
  config,
  lib,
  pkgs,
  nur-DataEraserC,
  ...
}:
let
  cfg = config.modules.mobileclaw;
in
{
  options.modules.mobileclaw.enable = lib.mkEnableOption "MobileClaw, China Mobile Cloud's AI office agent";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nur-DataEraserC.packages.${pkgs.stdenv.hostPlatform.system}.mobileclaw
    ];
  };
}
