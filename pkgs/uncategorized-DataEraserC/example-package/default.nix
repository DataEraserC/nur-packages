{
  lib,
  stdenv,
}:

stdenv.mkDerivation rec {
  name = "example-package-${version}";
  version = "1.0";
  src = ./.;
  buildPhase = ''
    runHook preBuild
    echo echo Hello World > example
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 example $out
    runHook postInstall
  '';
  meta = {
    description = "Example package demonstrating the repository packaging conventions";
    homepage = "https://github.com/DataEraserC/nur-packages";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
  };
}
