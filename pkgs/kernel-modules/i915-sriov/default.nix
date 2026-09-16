{
  fetchFromGitHub,
  unstableGitUpdater,
  stdenv,
  lib,
  kernel,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "i915-sriov";
  version = "2026.09.14-unstable-2026-09-16";
  src = fetchFromGitHub {
    owner = "strongtz";
    repo = "i915-sriov-dkms";
    rev = "6269bee86f6ab4645580ddb9b833d0124cc88a39";
    hash = "sha256-QSCFOc+1VQ0rzFDiQfTfqpIdx+D6FKGqtKAeCwVPz9U=";
  };
  hardeningDisable = [
    "pic"
    "format"
  ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  enableParallelBuilding = true;

  KSRC = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
  INSTALL_MOD_PATH = placeholder "out";

  makeFlags = kernel.commonMakeFlags or kernel.makeFlags;
  preBuild = ''
    makeFlags="$makeFlags -C ${finalAttrs.KSRC} M=$(pwd)"
  '';
  installTargets = [ "modules_install" ];

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/strongtz/i915-sriov-dkms";
  };
  meta = {
    maintainers = with lib.maintainers; [ xddxdd ];
    description = "DKMS module of Linux i915 driver with SR-IOV support";
    homepage = "https://github.com/strongtz/i915-sriov-dkms";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
})
