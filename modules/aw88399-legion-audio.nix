{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dataEraserC.aw88399-legion-audio;
in
{
  key = "DataEraserC-nur-packages-aw88399-legion-audio";

  options.dataEraserC.aw88399-legion-audio = {
    enable = lib.mkEnableOption (lib.mdDoc "Enable aw88399 audio support for Lenovo Legion laptops");
    patchVersion = lib.mkOption {
      type = lib.types.enum [
        "6.19.11"
        "7.0"
      ];
      default = "7.0";
      description = "Kernel patch version to use";
    };
    patchPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.aw88399-legion-audio-patch;
      description = "Package containing the audio patches";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.firmware = [ pkgs.aw88399-legion-firmware ];

    boot.kernelPatches = [
      {
        name = "aw88399-legion-audio";
        patch = cfg.patchPackage + "/16iax10h-audio-linux-${cfg.patchVersion}.patch";

        structuredExtraConfig = with lib.kernel; {
          SND_HDA_SCODEC_AW88399 = module;
          SND_HDA_SCODEC_AW88399_I2C = module;
          SND_SOC_AW88399 = module;
          SND_SOC_SOF_INTEL_TOPLEVEL = yes;
          SND_SOC_SOF_INTEL_COMMON = module;
          SND_SOC_SOF_INTEL_MTL = module;
          SND_SOC_SOF_INTEL_LNL = module;
        };
      }
    ];
  };
}
