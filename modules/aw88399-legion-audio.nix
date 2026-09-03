{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dataEraserC.aw88399-legion-audio;

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

  defaultKernelVersion = lib.getVersion pkgs.linux;

  isUsable = patchVersion: !(lib.versionOlder defaultKernelVersion patchVersion);

  usableVersions = lib.filter isUsable autoPatchVersions;

  autoVersion =
    if usableVersions == [ ] then
      null
    else
      lib.head (lib.sort (a: b: lib.versionOlder b a) usableVersions);

  selectedVersion =
    if cfg.patchVersion != null then
      cfg.patchVersion
    else if autoVersion == null then
      throw ''
        dataEraserC.aw88399-legion-audio: no archived patch is usable with the
        default kernel ${defaultKernelVersion}. Available auto-selectable
        versions: ${lib.concatStringsSep ", " autoPatchVersions}. Set the
        option `patchVersion' explicitly if you know the right one.
      ''
    else
      autoVersion;

  majorMinor =
    version:
    let
      match = builtins.match "([0-9]+)\\.([0-9]+).*" version;
    in
    if match == null then null else "${builtins.elemAt match 0}.${builtins.elemAt match 1}";

  actualKernelVersion = config.boot.kernelPackages.kernel.version;
in
{
  key = "DataEraserC-nur-packages-aw88399-legion-audio";

  options.dataEraserC.aw88399-legion-audio = {
    enable = lib.mkEnableOption (lib.mdDoc "Enable aw88399 audio support for Lenovo Legion laptops");
    patchVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = lib.mdDoc ''
        Kernel patch version to use. When null (default), the greatest
        archived version that is not newer than the kernel shipped by nixpkgs
        is picked automatically. Set it explicitly (e.g. `"7.1.8"`) to pin a
        version, which is required when the running kernel is not the one
        nixpkgs ships by default.
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

    assertions = [
      {
        assertion =
          cfg.patchVersion != null
          || majorMinor actualKernelVersion == null
          || majorMinor selectedVersion == majorMinor actualKernelVersion;
        message = ''
          dataEraserC.aw88399-legion-audio: auto-selected patch version
          ${selectedVersion} (for the nixpkgs default kernel
          ${defaultKernelVersion}) does not match the actually used kernel
          ${actualKernelVersion}. Set the option `patchVersion' explicitly to
          the version matching your kernel.
        '';
      }
    ];
  };
}
