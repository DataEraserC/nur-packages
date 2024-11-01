{
  lib,
  stdenv,
  makeBinaryWrapper,
  gradle_8,
  gradle ? gradle_8,
  jdk21,
  openjfx21,
  jdk21_with_openjfx ? jdk21.override (
    lib.optionalAttrs stdenv.hostPlatform.isLinux {
      enableJavaFX = true;
      openjfx21 = openjfx21.override { withWebKit = true; };
    }
  ),
  sources,
  libGL,
  xorg,
  libX11 ? xorg.libX11,
  libXrender ? xorg.libXrender,
  libXxf86vm ? xorg.libXxf86vm,
  libXtst ? xorg.libXtst,
}:
let
  jdk = jdk21_with_openjfx;
  self = stdenv.mkDerivation rec {
    inherit (sources.XiaoMiToolV2) pname version src;

    nativeBuildInputs = [
      gradle
      jdk
      makeBinaryWrapper
    ] ++ libraries;

    postPatch = ''
      sed -i "s/languageVersion = JavaLanguageVersion.of(17)//g" build.gradle
    '';

    # if the package has dependencies, mitmCache must be set
    mitmCache = gradle.fetchDeps {
      pkg = self;
      data = ./deps.json;
    };

    # this is required for using mitm-cache on Darwin
    __darwinAllowLocalNetworking = true;

    gradleFlags = [ "-Dfile.encoding=utf-8" ];

    gradleBuildTask = "build";

    doCheck = false;

    libraries = [
      libGL
      libX11
      libXrender
      libXxf86vm
      libXtst
    ];

    runtimeLibs = lib.makeLibraryPath libraries;

    installPhase = ''
      mkdir -p $out/{bin,share/XiaoMiToolV2/bin}

      tar xf build/distributions/XiaomiToolV2-shadow-*.tar --directory=$out/share/XiaoMiToolV2

      extracted_dir=$(find $out/share/XiaoMiToolV2 -maxdepth 1 -type d -name "XiaomiToolV2-shadow-*")

      mv $extracted_dir/bin $out/share/XiaoMiToolV2
      mv $extracted_dir/lib $out/share/XiaoMiToolV2
      ln -s $out/share/XiaoMiToolV2/lib/XiaomiToolV2-*-all.jar $out/share/XiaoMiToolV2/lib/XiaoMiTool.jar
      rm -rf $extracted_dir

      makeWrapper "$out/share/XiaoMiToolV2/bin/XiaoMiTool V2" $out/bin/XiaoMiToolV2 \
        --set JAVA_HOME "${jdk}" \
        --prefix LD_LIBRARY_PATH : "${runtimeLibs}"
    '';

    meta.sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode # mitm cache
    ];
  };
in
self
