#https://github.com/jkarni/flake/blob/cb9c3ac7b52e996fe03977b85022a50054892d69/pkgs/snell/default.nix#L15
{
  stdenvNoCC,
  unzip,
  buildFHSEnv,
  writeShellScript,
  fetchurl,
  stdenv,
  ...
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "i686-linux"
    "aarch64-linux"
    "aarch32-linux"
  ];
  HostPlatform = stdenv.hostPlatform.system;

  version =
    {
      x86_64-linux = "v6.0.0rc2";
      i686-linux = "v6.0.0rc2";
      aarch64-linux = "v6.0.0rc2";
      aarch32-linux = "v5.0.1";
    }
    .${HostPlatform} or (throw "Unsupported platform: ${HostPlatform}");

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://dl.nssurge.com/snell/snell-server-v6.0.0rc2-linux-amd64.zip";
        hash = "sha256-ipxEY8qHz6Xqo3xq8NN6uT6idaoSORmFuyo3XKOr1/I=";
      };
      i686-linux = fetchurl {
        url = "https://dl.nssurge.com/snell/snell-server-v6.0.0rc2-linux-i386.zip";
        hash = "sha256-ZwYO95rE7wu2TFIDAjlmILOgb49tXOtFC+KD5Pp0kzU=";
      };
      aarch64-linux = fetchurl {
        url = "https://dl.nssurge.com/snell/snell-server-v6.0.0rc2-linux-aarch64.zip";
        hash = "sha256-oLKRXLx33Duvj6Bp50HCCAjYoQw6ipPnCaClgGRcO9c=";
      };
      aarch32-linux = fetchurl {
        url = "https://dl.nssurge.com/snell/snell-server-v5.0.1-linux-armv7l.zip";
        hash = "sha256-FEifPoV1aciDXdNZi36mvKU3HUKQrHzw9sjfszgcH7I=";
      };
    }
    .${HostPlatform};
  snell-static = stdenvNoCC.mkDerivation {
    pname = "snell-server-unwrapped";
    inherit version src;
    buildInputs = [ unzip ];

    phases = [
      "unpackPhase"
      "installPhase"
    ];

    unpackPhase = ''
      unzip $src
    '';

    installPhase = ''
      mkdir -p $out
      cp snell-server $out
    '';

    meta = {
      description = "https://manual.nssurge.com/others/snell.html";
      platforms = SupportedPlatforms;
    };
  };
in
(buildFHSEnv {
  name = "snell";
  runScript = writeShellScript "snell-run" ''
    exec ${snell-static}/snell-server "$@"
  '';
}).overrideAttrs
  (old: {
    passthru = (old.passthru or { }) // {
      updateScript = [ (toString ./update.sh) ];
    };
  })
