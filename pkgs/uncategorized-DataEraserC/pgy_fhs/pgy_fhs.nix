{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  dpkg,
  buildFHSEnv,
  writeShellScript,
  dataDir ? null,
  configFile ? null,
  ...
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "i686-linux"
    "aarch64-linux"
    "armv7l-linux"
  ];
  HostPlatform = stdenv.hostPlatform.system;
  version = "6.9.0";

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://dl.oray.com/pgy/linux/PgyVisitor-${version}-amd64.deb";
        hash = "sha256-OlPhs2Jm9QMcm001wC3xhYNDf+2zhKWOiX3efCrItg0=";
      };
      i686-linux = fetchurl {
        url = "https://dl.oray.com/pgy/linux/PgyVisitor-${version}-i386.deb";
        hash = "sha256-6jbLatpVyNwBQ4y8Sj3zNGW87s108cb3/yGAnPGig00=";
      };
      aarch64-linux = fetchurl {
        url = "https://dl.oray.com/pgy/linux/PgyVisitor-${version}-arm64.deb";
        hash = "sha256-/ymgLcnSwZ4ZeCiM1DkEzh1gZt1c4jcZbeuAAGagxlk=";
      };
      armv7l-linux = fetchurl {
        url = "https://dl.oray.com/pgy/linux/PgyVisitor-${version}-arm32.deb";
        hash = "sha256-vaCCqtRckp9QGem7BgUkb12e7/qd8LuTr6EtZ05HgvA=";
      };
    }
    .${HostPlatform};
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "pgyvisitor-unwrapped";
    inherit version src;
    nativeBuildInputs = [ dpkg ];
    dontConfigure = true;
    dontBuild = true;
    sourceRoot = "debroot";
    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x $src debroot
      runHook postUnpack
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/share/pgyvpn $out/etc/oray/pgyvpn
      for bin in usr/sbin/*; do
        install -Dm755 "$bin" "$out/bin/$(basename "$bin")"
      done
      cp -r usr/share/pgyvpn/. $out/share/pgyvpn/
      install -Dm644 etc/oray/pgyvpn/config.ini $out/etc/oray/pgyvpn/config.ini
      runHook postInstall
    '';
  };
  dispatch = writeShellScript "pgy" ''
    case "''${1:-}" in
      pgyvisitor|pgyvpn_svr|pgystarnet)
        cmd="$1"
        shift
        exec /usr/bin/"$cmd" "$@"
        ;;
      -h|--help|help|"")
        echo "用法: pgy <命令> [参数...]"
        echo "命令:"
        echo "  pgyvisitor    PgyVisitor 客户端"
        echo "  pgyvpn_svr    PgyVPN 守护进程"
        echo "  pgystarnet    星状网络工具"
        exit 0
        ;;
      *)
        echo "pgy: 未知命令 “''${1}”" >&2
        echo "用法: pgy <命令> [参数...]" >&2
        echo "可用命令: pgyvisitor pgyvpn_svr pgystarnet" >&2
        exit 1
        ;;
    esac
  '';
in
(buildFHSEnv {
  name = "pgy";
  targetPkgs = _: [ unwrapped ];
  runScript = dispatch;
  extraBwrapArgs =
    (lib.optional (dataDir != null) "--bind ${dataDir} /etc/oray/pgyvpn")
    ++ (lib.optional (configFile != null) "--bind ${configFile} /etc/oray/pgyvpn/config.ini");
  meta = {
    homepage = "https://pgy.oray.com/download/";
    description = "Client for the Oray PgyVisitor software-defined networking platform";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ xddxdd ];
    mainProgram = "pgy";
    platforms = SupportedPlatforms;
  };
}).overrideAttrs
  (old: {
    passthru = (old.passthru or { }) // {
      updateScript = [ (toString ./update.sh) ];
    };
  })
