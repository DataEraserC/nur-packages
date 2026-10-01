{
  fetchFromGitHub,
  unstableGitUpdater,
  stdenv,
  lib,
  cmake,
  pkg-config,
  oniguruma,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "qsp-lib";
  version = "5.9.5-unstable-2026-10-01";
  src = fetchFromGitHub {
    owner = "QSPFoundation";
    repo = "qsp";
    rev = "1fabc7e858eb08041e3c209e66a91a3ec3468dec";
    hash = "sha256-Rt+5CfgU0KpU759tmCm0EbWZzeyVMXOEMr9IcoTBz10=";
  };
  prePatch = ''
    install -Dm644 ${./QspConfig.cmake.in} QspConfig.cmake.in
    substituteInPlace CMakeLists.txt \
      --replace-fail " onig " " "
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  buildInputs = [ oniguruma ];

  cmakeFlags = [ (lib.cmakeBool "USE_INSTALLED_ONIGURUMA" true) ];

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/QSPFoundation/qsp";
  };
  meta = {
    maintainers = with lib.maintainers; [ xddxdd ];
    description = "Interactive fiction development platform (Game Library)";
    homepage = "https://github.com/QSPFoundation/qsp";
    license = lib.licenses.gpl2Only;
  };
})
