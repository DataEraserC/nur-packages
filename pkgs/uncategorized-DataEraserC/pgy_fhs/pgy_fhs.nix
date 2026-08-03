{
  lib,
  stdenv,
  stdenvNoCC,
  sources,
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
  SourceMap = {
    x86_64-linux = "AAA_pgylinux-amd64";
    i686-linux = "AAA_pgylinux-i386";
    aarch64-linux = "AAA_pgylinux-arm64";
    armv7l-linux = "AAA_pgylinux-arm32";
  };
  source = sources.${SourceMap.${HostPlatform} or (throw "Unsupported platform: ${HostPlatform}")};
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "pgyvisitor-unwrapped";
    inherit (source) version src;
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
buildFHSEnv {
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
}
