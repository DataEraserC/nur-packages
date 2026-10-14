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
  version = "2.3.91093";

  plat =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hash =
    {
      x86_64-linux = "sha256-w7zIVtuqwdh9oQzd+mx63pe0eAwLyJRPGy0D4URUDfE=";
      aarch64-linux = "sha256-H14/DOCDPlcMLPyAj3/yaNs6spVQon0BS3mbKIHk+fo=";
    }
    .${stdenv.hostPlatform.system};
in
(buildVscode {
  pname = "trae-intl";
  inherit version;

  executableName = "trae";
  longName = "Trae";
  shortName = "Trae";
  iconName = "trae";
  libraryName = "trae";
  vscodeVersion = "1.107.1";

  commandLineArgs = "";
  sourceRoot = ".";

  src = fetchurl {
    url = "https://lf-cdn.trae.ai/obj/trae-ai-us/pkg/app/releases/stable/${version}/linux/TRAE-linux-${plat}.tar.gz";
    inherit hash;
  };

  updateScript = ./update.sh;

  tests = { };

  meta = {
    description = "AI-powered IDE by ByteDance with global model services";
    homepage = "https://www.trae.ai/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
    mainProgram = "trae";
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
