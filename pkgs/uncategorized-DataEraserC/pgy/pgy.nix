{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  perl,
  makeWrapper,
  patchelf,
  bash,
  coreutils,
  iproute2,
  iptables,
  nettools,
  procps,
  psmisc,
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

  # pgyvpn_svr shells out to these tools, and both daemons need a POSIX shell
  # for their iptables/route/status helpers.
  runtimePath = lib.makeBinPath [
    bash
    coreutils
    iproute2
    iptables
    nettools
    procps
    psmisc
  ];

  # patchelf 0.18+ rewrites these old non-PIE binaries into a layout whose
  # overlapping LOAD segments make the dynamic loader fault on startup
  # (relocations land in a read-only page). 0.15.2 still produces a sane
  # layout, so pin it and patch the interpreter/RPATH by hand.
  patchelf_0_15 = patchelf.overrideAttrs (_: {
    version = "0.15.2";
    src = fetchurl {
      url = "https://github.com/NixOS/patchelf/releases/download/0.15.2/patchelf-0.15.2.tar.bz2";
      hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
    };
  });

  dynamicLinker = stdenv.cc.bintools.dynamicLinker;
  runtimeLibs = lib.makeLibraryPath [
    stdenv.cc.cc.lib
    stdenv.cc.cc.libgcc
  ];
in
stdenv.mkDerivation {
  pname = "pgy";
  inherit version src;

  passthru.updateScript = [ (toString ./update.sh) ];

  nativeBuildInputs = [
    dpkg
    perl
    makeWrapper
    patchelf_0_15
  ];
  buildInputs = [
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;
  sourceRoot = "debroot";

  # These old binaries must be stripped before patchelf rewrites their
  # interpreter/RPATH; stripping afterwards leaves a layout the loader rejects.
  # Strip here and disable stdenv's automatic post-fixup strip.
  dontStrip = true;
  preFixup = ''
    strip $out/libexec/pgy/pgyvisitor $out/libexec/pgy/pgyvpn_svr
  '';

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src debroot
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/libexec/pgy $out/share/pgyvpn $out/etc/oray/pgyvpn
    for bin in usr/sbin/*; do
      install -Dm755 "$bin" "$out/libexec/pgy/$(basename "$bin")"
    done
    cp -r usr/share/pgyvpn/. $out/share/pgyvpn/
    install -Dm644 etc/oray/pgyvpn/config.ini $out/etc/oray/pgyvpn/config.ini

    # The bundled binaries look for their resources at /usr/share/pgyvpn.
    # Every command wrapper changes into $out first, so a relative path keeps
    # the package free of any FHS sandbox without touching the host.
    cat > $out/bin/pgy <<'EOF'
    #!@bash@/bin/bash
    set -euo pipefail
    if [ "$#" -eq 0 ]; then
      set -- --help
    fi
    case "$1" in
      pgyvisitor|pgyvpn_svr|pgystarnet)
        cmd="$1"
        shift
        exec "$(dirname "$(readlink -f "$0")")/$cmd" "$@"
        ;;
      -h|--help|help)
        echo "用法: pgy <命令> [参数...]"
        echo "命令:"
        echo "  pgyvisitor    PgyVisitor 客户端"
        echo "  pgyvpn_svr    PgyVPN 守护进程"
        echo "  pgystarnet    星状网络工具"
        exit 0
        ;;
      *)
        echo "pgy: 未知命令 “$1”" >&2
        echo "用法: pgy <命令> [参数...]" >&2
        echo "可用命令: pgyvisitor pgyvpn_svr pgystarnet" >&2
        exit 1
        ;;
    esac
    EOF
    substituteInPlace $out/bin/pgy --subst-var-by bash "${bash}"
    chmod +x $out/bin/pgy
    runHook postInstall
  '';

  postFixup = ''
    runHook prePostFixup

    # Replace a string inside an ELF binary in place. The replacement must not
    # be longer than the original; the remaining bytes are NUL-padded.
    patchString() {
      local file="$1" old="$2" new="$3"
      perl -e '
        my ($f, $old, $new) = @ARGV;
        open my $in, "<:raw", $f or die "$f: $!";
        local $/;
        my $data = <$in>;
        close $in;
        die "$old does not fit into $f" if length($new) > length($old);
        my $repl = $new . pack("x" . (length($old) - length($new)));
        my $i = 0;
        my $count = 0;
        while (($i = index($data, $old, $i)) >= 0) {
          substr($data, $i, length($old)) = $repl;
          $i += length($old);
          $count++;
        }
        die "$old not found in $f" if $count == 0;
        open my $out, ">:raw", $f or die "$f: $!";
        print $out $data;
        close $out;
      ' "$file" "$old" "$new"
    }

    patchString $out/libexec/pgy/pgyvisitor /usr/share/pgyvpn ./share/pgyvpn///
    patchString $out/libexec/pgy/pgyvpn_svr /usr/share/pgyvpn ./share/pgyvpn///
    patchString $out/libexec/pgy/pgyvpn_svr /usr/sbin/pgystarnet ./bin/pgystarnet
    patchString $out/libexec/pgy/pgyvpn_svr /usr/sbin/pgyvpn_proxy ./bin/pgyvpn_proxy

    for cmd in pgyvisitor pgyvpn_svr; do
      patchelf \
        --set-interpreter ${dynamicLinker} \
        --set-rpath ${runtimeLibs} \
        $out/libexec/pgy/$cmd
    done

    for cmd in pgyvisitor pgyvpn_svr pgystarnet; do
      makeWrapper $out/libexec/pgy/$cmd $out/bin/$cmd \
        --chdir $out \
        --prefix PATH : ${runtimePath}
    done

    runHook postPostFixup
  '';

  meta = with lib; {
    homepage = "https://pgy.oray.com/download/";
    description = "Client for the Oray PgyVisitor software-defined networking platform";
    license = licenses.unfree;
    maintainers = import ../maintainers.nix;
    mainProgram = "pgy";
    platforms = SupportedPlatforms;
  };
}
