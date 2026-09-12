{
  fetchFromGitHub,
  lib,
  unstableGitUpdater,
  stdenv,
  python3,
  makeWrapper,
  curl,
}:
let
  python = python3.withPackages (
    p: with p; [
      aiofiles
      aiosqlite
      cryptography
      fastapi
      greenlet
      h2
      httpx
      httpx-socks
      msgspec
      pillow
      pytest
      python-multipart
      ruamel-yaml
      sqlalchemy
      uvicorn
      watchfiles
      xue
      zstandard
    ]
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "uni-api";
  version = "1.7.273-unstable-2026-09-12";
  src = fetchFromGitHub {
    owner = "yym68686";
    repo = "uni-api";
    rev = "360bf0b2ba9b902b29070b2359124be2c01fe46e";
    fetchSubmodules = true;
    hash = "sha256-9t98ISVVy196SKGN8ddwN8FFa6rAeoVIacmez8tOda4=";
  };
  nativeBuildInputs = [
    makeWrapper
    curl
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck

    ${python}/bin/python -c "import uni_api.app"

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt
    cp -r * $out/opt/

    makeWrapper ${python}/bin/python $out/bin/uni-api \
      --add-flags "-m" \
      --add-flags "uvicorn" \
      --add-flags "--app-dir" \
      --add-flags "$out/opt" \
      --add-flags "main:app"

    runHook postInstall
  '';

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/yym68686/uni-api";
    tagPrefix = "v";
  };
  meta = {
    maintainers = with lib.maintainers; [ xddxdd ];
    description = "Unifies the management of LLM APIs across multiple backend services";
    homepage = "https://github.com/yym68686/uni-api";
    license = lib.licenses.unfree;
    mainProgram = "uni-api";
  };
})
