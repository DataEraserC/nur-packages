{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  cmake,
  ninja,
  pkg-config,
  curl,
  libGL,
  libX11,
  libXi,
  libXfixes,
  makeWrapper,
}:

let
  version = "1.12.0";
  src = fetchFromGitHub {
    owner = "vladelaina";
    repo = "BongoCat";
    tag = "v${version}";
    hash = "sha256-I8rJ8ocFoMQppRJM6izYitml2PL5fMQWC3RHuZhyyps=";
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

  minizSrc = fetchurl {
    name = "miniz-source";
    url = "https://codeload.github.com/richgel999/miniz/tar.gz/refs/tags/3.1.0";
    hash = "sha256-CVafwZ0GCsn1mZupNWcowklOvmokrA6wprauPTls/qY=";
  };

  webpSrc = fetchurl {
    name = "libwebp-source";
    url = "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz";
    hash = "sha256-5KtwCb8GKf0RmC1MKqg5ZM8kTP+6c0fs05AZqeOMRWQ=";
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
    {
      name = "miniz";
      src = minizSrc;
    }
    {
      name = "about_webp";
      src = webpSrc;
    }
  ];

  unwrapped = stdenv.mkDerivation (finalAttrs: {
    pname = "BongoCat-unwrapped";
    inherit version src;

    nativeBuildInputs = [
      cmake
      ninja
      pkg-config
    ];

    buildInputs = [
      curl
      libGL
      libX11
      libXi
      libXfixes
    ];

    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      cp -r ${src} source
      chmod -R +w source
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
        -DBONGO_CAT_REQUIRE_CUBISM=OFF \
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
      ];
    };

    meta = {
      description = "Interactive desktop companion with real-time reactions to keyboard, mouse, and gamepad input";
      homepage = "https://github.com/vladelaina/BongoCat";
      changelog = "https://github.com/vladelaina/BongoCat/releases/tag/v${version}";
      license = lib.licenses.agpl3Only;
      platforms = lib.platforms.linux;
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
    makeWrapper ${unwrapped}/share/BongoCat/BongoCat $out/bin/BongoCat
    runHook postInstall
  '';

  inherit (unwrapped) meta;
}
