{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  perl,
  makeWrapper,
  autoPatchelfHook,
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
in
stdenv.mkDerivation {
  pname = "pgy";
  inherit version src;

  passthru.updateScript = [ (toString ./update.sh) ];

  nativeBuildInputs = [
    dpkg
    perl
    makeWrapper
    autoPatchelfHook
  ];
  buildInputs = [
    stdenv.cc.cc.lib
  ];

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

  postFixup = ''
    runHook prePostFixup
    perl -e '
      my $f = shift;
      open my $fh, "<:raw", $f or die;
      local $/;
      my $d = <$fh>;
      close $fh;
      my $old = "/usr/share/pgyvpn";
      my $new = "./share/pgyvpn///";
      my $i = 0;
      while (($i = index($d, $old, $i)) >= 0) {
        substr($d, $i, length($old)) = $new;
        $i += length($new);
      }
      open my $out, ">:raw", $f or die;
      print $out $d;
      close $out;
    ' $out/bin/pgyvisitor
    mkdir -p $out/libexec
    mv $out/bin/pgyvisitor $out/libexec/pgyvisitor
    makeWrapper $out/libexec/pgyvisitor $out/bin/pgyvisitor --chdir $out
    runHook postPostFixup
  '';

  meta = with lib; {
    homepage = "https://pgy.oray.com/download/";
    description = "Client for the Oray PgyVisitor software-defined networking platform";
    license = licenses.unfree;
    maintainers = with lib.maintainers; [ xddxdd ];
    mainProgram = "pgyvisitor";
    broken = true;
    platforms = SupportedPlatforms;
  };
}
