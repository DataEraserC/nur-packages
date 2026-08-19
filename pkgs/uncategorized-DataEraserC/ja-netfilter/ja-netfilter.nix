{
  stdenvNoCC,
  fetchzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ja-netfilter";
  version = "240701";

  src = fetchzip {
    url = "https://3.jetbra.in/files/jetbra-5a50fc03d68a014f893b7fc3aa465380d59f9095.zip";
    sha256 = "sha256-iCtLAmJ1uBU2VtU/EbgASI5Ws9pUJUpWxOB6xsZjgVs=";
  };

  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out

    cp ja-netfilter.jar $out
    cp -r config-jetbrains $out
    cp -r plugins-jetbrains $out

    runHook postInstall
  '';

  meta = {
    description = "ja-netfilter";
    homepage = "https://3.jetbra.in";
  };
})
