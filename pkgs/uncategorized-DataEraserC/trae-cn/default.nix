{
  lib,
  stdenv,
  buildVscode,
  fetchurl,
  curl,
  xz,
  zlib,
  glib,
  gtk3,
  gnutls,
  libgcrypt,
  dbus,
  cups,
  expat,
  cairo,
  pango,
  libxkbcommon,
}:
let
  version = "2.3.92182";

  plat =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hash =
    {
      x86_64-linux = "sha256-2znRXowgobZguIKsuWiicnpsMdA05FqXZBbn7KcVZiQ=";
      aarch64-linux = "sha256-zexMk2Iyn1y50rfKyTHmnaycMGfo27D3AYHo41YNl50=";
    }
    .${stdenv.hostPlatform.system};
in
(buildVscode {
  pname = "trae-cn";
  inherit version;

  executableName = "trae-cn";
  longName = "Trae CN";
  shortName = "Trae CN";
  iconName = "trae-cn";
  libraryName = "trae-cn";
  vscodeVersion = "1.107.1";

  commandLineArgs = "";
  sourceRoot = ".";

  src = fetchurl {
    url = "https://lf-cdn.trae.com.cn/obj/trae-com-cn/pkg/app/releases/stable/${version}/linux/TRAE_CN-linux-${plat}.tar.gz";
    inherit hash;
  };

  updateScript = ./update.sh;

  tests = { };

  meta = {
    description = "ByteDance AI-powered IDE with China-region model services";
    homepage = "https://www.trae.cn/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
    mainProgram = "trae-cn";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}).overrideAttrs
  (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [
      curl
      xz
      zlib
      glib
      gtk3
      gnutls
      libgcrypt
      dbus
      cups
      expat
      cairo
      pango
      libxkbcommon
    ];

    passthru = (old.passthru or { }) // {
      aiProvenance = [
        {
          agent = "dsh";
          involvement = "authored";
        }
      ];
    };

    autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
      "libc.musl-*.so.*"
    ];
  })
