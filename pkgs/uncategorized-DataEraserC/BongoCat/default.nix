{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  cmake,
  ninja,
  pkg-config,
  wayland-scanner,
  curl,
  libGL,
  libX11,
  libXi,
  libXfixes,
  wayland,
  libxkbcommon,
  libffi,
  makeWrapper,
  unzip,
  gtk3,
  libayatana-appindicator,
  libappindicator-gtk3,
}:

let
  version = "1.14.0";
  src = fetchFromGitHub {
    owner = "vladelaina";
    repo = "BongoCat";
    tag = "v${version}";
    hash = "sha256-u8k+yaKeH27bq3W6vUPR70pSG+fXMD+fpfLVmXE7WMw=";
  };

  sdl3 = fetchurl {
    name = "sdl3-source";
    url = "https://github.com/libsdl-org/SDL/archive/402fc52af4e731184ad6a704068b5ccd27d8f1b8.tar.gz";
    hash = "sha256-5BMVGvccI9MWtgdqlqmZNCFCr6eSOU6vilQqA1A/xJE=";
  };

  yyjsonSrc = fetchurl {
    name = "yyjson-source";
    url = "https://github.com/ibireme/yyjson/archive/ac8f6074e1fbc43ec496aa1404b460d08b55d7a5.tar.gz";
    hash = "sha256-v8FuQH3bMDyY4zOSDV4BOGr6QqFeCnUCUTQuBLB05zY=";
  };

  stbSrc = fetchurl {
    name = "stb-source";
    url = "https://github.com/nothings/stb/archive/31c1ad37456438565541f4919958214b6e762fb4.tar.gz";
    hash = "sha256-5OO7qcVypKQUg3OpFNiOoPDRHejMLGZzmSbn7KAiMxk=";
  };

  miniaudioSrc = fetchurl {
    name = "miniaudio-source";
    url = "https://github.com/mackron/miniaudio/archive/9634bedb5b5a2ca38c1ee7108a9358a4e233f14d.tar.gz";
    hash = "sha256-Gjp5uA/G8LDMFV4ouVSlmODd+i22Tir6hGa+iMR2+lU=";
  };

  nuklearSrc = fetchurl {
    name = "nuklear-source";
    url = "https://github.com/Immediate-Mode-UI/Nuklear/archive/8109cfbabe04f8705408c5d8ab1a6cd48649ccda.tar.gz";
    hash = "sha256-I+XhsS6Jfx1WjrcDqjE7ciTJt14RGHZM66R30TuOOfQ=";
  };

  cubismSdk = fetchurl {
    url = "https://cubism.live2d.com/sdk-native/bin/CubismSdkForNative-5-r.5.zip";
    hash = "sha256-f/Oku8GcCocollqlIqt36xGyUpFkU+aKinjTtxGIuxI=";
  };

  glewSrc = fetchurl {
    url = "https://github.com/nigels-com/glew/releases/download/glew-2.2.0/glew-2.2.0.zip";
    hash = "sha256-qQRqkTd0OVoJXtzAsKwtgcOqzKYXh7OYOblB6b4U4NQ=";
  };

  deps = [
    {
      name = "SDL3";
      src = sdl3;
    }
    {
      name = "yyjson";
      src = yyjsonSrc;
    }
    {
      name = "stb";
      src = stbSrc;
    }
    {
      name = "miniaudio";
      src = miniaudioSrc;
    }
    {
      name = "nuklear";
      src = nuklearSrc;
    }
  ];

  unwrapped = stdenv.mkDerivation (finalAttrs: {
    pname = "BongoCat-unwrapped";
    inherit version src;

    nativeBuildInputs = [
      cmake
      ninja
      pkg-config
      wayland-scanner
      unzip
    ];

    buildInputs = [
      curl
      libGL
      libX11
      libXi
      libXfixes
      libffi
    ];

    propagatedBuildInputs = [
      wayland
      libxkbcommon
    ];

    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      cp -r ${src} source
      chmod -R +w source

      mkdir -p source/vendor/CubismSdkForNative
      unzip -q ${cubismSdk} -d "$TMPDIR/cubism"
      core_header=$(find "$TMPDIR/cubism" -maxdepth 4 -path "*/Core/include/Live2DCubismCore.h" | head -n 1)
      if [ -z "$core_header" ]; then
        echo "Cubism SDK archive layout unexpected: Core/include/Live2DCubismCore.h not found" >&2
        exit 1
      fi
      sdk_root=$(dirname "$(dirname "$(dirname "$core_header")")")
      cp -r "$sdk_root/Core" "$sdk_root/Framework" source/vendor/CubismSdkForNative/

      unzip -q ${glewSrc} -d "$TMPDIR/glew"
      glew_cmake=$(find "$TMPDIR/glew" -maxdepth 4 -path "*/build/cmake/CMakeLists.txt" | head -n 1)
      if [ -z "$glew_cmake" ]; then
        echo "GLEW archive layout unexpected: build/cmake/CMakeLists.txt not found" >&2
        exit 1
      fi
      glew_root=$(dirname "$(dirname "$(dirname "$glew_cmake")")")
      mkdir -p source/vendor/CubismSdkForNative/Samples/OpenGL/thirdParty
      mv "$glew_root" source/vendor/CubismSdkForNative/Samples/OpenGL/thirdParty/glew

      runHook postUnpack
    '';

    configurePhase = ''
      runHook preConfigure

      mkdir -p source/_fetchcontent_cache
      ${lib.concatStringsSep "\n" (
        map (dep: ''
          mkdir -p source/_fetchcontent_cache/${dep.name}
          tar -xzf ${dep.src} -C source/_fetchcontent_cache/${dep.name} --strip-components=1
        '') deps
      )}

      cmakeCache=source/_fetchcontent_cache/cmake-initial-cache.cmake
      echo 'set(FETCHCONTENT_FULLY_DISCONNECTED ON CACHE BOOL "" FORCE)' > "$cmakeCache"
      ${lib.concatStringsSep "\n" (
        map (dep: ''
          echo "set(FETCHCONTENT_SOURCE_DIR_${lib.toUpper dep.name} \"$PWD/source/_fetchcontent_cache/${dep.name}\" CACHE PATH \"\" FORCE)" >> "$cmakeCache"
        '') deps
      )}

      cmake -S source -B build \
        -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF \
        -DBONGO_CAT_FETCH_DEPS=ON \
        -DBONGO_CAT_CUBISM_SDK="$PWD/source/vendor/CubismSdkForNative" \
        -DBONGO_CAT_REQUIRE_CUBISM=ON \
        -C "$cmakeCache"

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      ninja -C build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/BongoCat
      install -Dm755 build/BongoCat $out/share/BongoCat/BongoCat
      cp -r source/resources/assets $out/share/BongoCat/assets

      runHook postInstall
    '';

    passthru = {
      updateScript = [ (toString ./update.sh) ];
      aiProvenance = [
        {
          agent = "dsh";
          model = "deepseek-v4-flash";
          involvement = "assisted";
        }
        {
          agent = "dsh";
          model = "mimo-v2.6-flash-free";
          involvement = "assisted";
        }
      ];
    };

    meta = {
      description = "Interactive desktop companion with real-time reactions to keyboard, mouse, and gamepad input";
      homepage = "https://github.com/vladelaina/BongoCat";
      changelog = "https://github.com/vladelaina/BongoCat/releases/tag/v${version}";
      license = lib.licenses.agpl3Only;
      platforms = [ "x86_64-linux" ];
      maintainers = import ../maintainers.nix;
      mainProgram = "BongoCat";
    };
  });
in
stdenv.mkDerivation {
  pname = "BongoCat";
  inherit (unwrapped) version;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    makeWrapper ${unwrapped}/share/BongoCat/BongoCat $out/bin/BongoCat \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          wayland
          libxkbcommon
          gtk3
          libayatana-appindicator
          libappindicator-gtk3
        ]
      }"
    runHook postInstall
  '';

  passthru = {
    aiProvenance = [
      {
        agent = "dsh";
        model = "mimo-v2.6-flash-free";
        involvement = "assisted";
      }
    ];
  };

  inherit (unwrapped) meta;
}
