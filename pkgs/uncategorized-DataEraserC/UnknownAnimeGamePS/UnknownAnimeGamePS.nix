{
  lib,
  stdenv,
  makeBinaryWrapper,
  gradle,
  jdk22,
  sources,
}:
let
  self = stdenv.mkDerivation {
    inherit (sources.UnknownAnimeGamePS) pname version src;

    nativeBuildInputs = [
      gradle
      makeBinaryWrapper
    ];

    # if the package has dependencies, mitmCache must be set
    mitmCache = gradle.fetchDeps {
      pkg = self;
      data = ./deps.json;
    };

    # this is required for using mitm-cache on Darwin
    __darwinAllowLocalNetworking = true;

    gradleFlags = [ "-Dfile.encoding=utf-8" ];

    gradleBuildTask = "jar";

    doCheck = false;

    installPhase = ''
      mkdir -p $out/{bin,share/UnknownAnimeGamePS}
      cp UnknownAnimeGamePS*.jar $out/share/UnknownAnimeGamePS/UnknownAnimeGamePS.jar

      makeWrapper ${jdk22}/bin/java $out/bin/UnknownAnimeGamePS \
        --add-flags "-jar $out/share/UnknownAnimeGamePS/UnknownAnimeGamePS.jar"
    '';

    meta.sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode # mitm cache
    ];
  };
in
self
