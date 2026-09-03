{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.hardware.audio.aw88399-legion-audio;

  autoPatchVersions = [
    "6.17.8"
    "6.17.9"
    "6.18"
    "6.19"
    "6.19.8"
    "6.19.11"
    "7.0"
    "7.0.13"
    "7.0.14"
    "7.1.2"
    "7.1.3"
    "7.1.5"
    "7.1.6"
    "7.1.8"
    "7.2"
  ];

  majorMinor =
    version:
    let
      match = builtins.match "([0-9]+)\\.([0-9]+).*" version;
    in
    if match == null then null else "${builtins.elemAt match 0}.${builtins.elemAt match 1}";

  actualKernelVersion = lib.getVersion config.boot.kernelPackages.kernel;

  matchesRunningKernel = patchVersion: majorMinor patchVersion == majorMinor actualKernelVersion;

  isNotNewerThanRunningKernel = patchVersion: !(lib.versionOlder actualKernelVersion patchVersion);

  candidates = lib.filter (
    patchVersion: isNotNewerThanRunningKernel patchVersion && matchesRunningKernel patchVersion
  ) autoPatchVersions;

  autoVersion =
    if candidates == [ ] then null else lib.head (lib.sort (a: b: lib.versionOlder b a) candidates);

  selectedVersion =
    if cfg.patchVersion != null then
      cfg.patchVersion
    else if autoVersion == null then
      throw ''
        hardware.audio.aw88399-legion-audio: no archived patch matches the
        running kernel ${actualKernelVersion}. Auto-selectable archived
        versions: ${lib.concatStringsSep ", " autoPatchVersions}. If the kernel
        is at least 7.3 the driver is already part of mainline, so the module
        can simply be disabled. Otherwise set the option `patchVersion'
        explicitly if you know the right version to use.
      ''
    else
      autoVersion;
in
{
  key = "hardware-aw88399-legion-audio";

  options.hardware.audio.aw88399-legion-audio = {
    enable = lib.mkEnableOption (lib.mdDoc "Enable aw88399 audio support for Lenovo Legion laptops");
    patchVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = lib.mdDoc ''
        Kernel patch version to use. When null (default), the greatest
        archived version whose major/minor series matches the running kernel
        (`boot.kernelPackages`) and that is not newer than it is picked
        automatically. Set it explicitly (e.g. `"7.1.8"`) to pin a version.
      '';
    };
    patchPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.aw88399-legion-audio-patch;
      description = "Package containing the audio patches";
    };
    firmwarePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.aw88399-legion-firmware;
      description = "Package containing the aw88399 firmware";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.firmware = [ cfg.firmwarePackage ];

    boot.kernelPatches = [
      {
        name = "aw88399-legion-audio";
        patch = cfg.patchPackage + "/16iax10h-audio-linux-${selectedVersion}.patch";

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
