# ZCode Source Server: the headless runtime the desktop app installs over SSH.
#
# The desktop keeps it at ~/.zcode/server and talks to it over an ingress
# socket; packaged here it runs from the store instead, so a machine needs no
# desktop app and no writable installation tree. The archive lives next to the
# desktop releases on the same CDN (`electron/releases/<version>/`).
#
# `bin/zcode` is a shell script that resolves the release root from its own
# location and runs the bundled Node runtime, so the whole tree stays together
# under libexec and only a thin wrapper reaches bin/.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  zcode-cli,
}:
let
  sources = import ./sources.nix;
  inherit (stdenv.hostPlatform) system;
  asset = sources.assets.${system} or (throw "zcode-server: no release for ${system}");
in
stdenv.mkDerivation {
  pname = "zcode-server";
  inherit (sources) version;

  src = fetchurl {
    url = "https://cdn-zcode.z.ai/zcode/electron/releases/${sources.version}/${asset.name}";
    inherit (asset) sha256;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # runtime/node is the official prebuilt Node; it wants libstdc++ on top of
  # glibc, and autoPatchelf rewrites the interpreter for NixOS.
  buildInputs = [
    stdenv.cc.cc.lib
    stdenv.cc.libc
  ];

  # The tree carries prebuilt binaries for every platform (koffi and friends
  # ship musl variants that never load on NixOS/glibc).
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libc.musl-aarch64.so.1"
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    mkdir -p source
    tar -xzf $src -C source --strip-components=1
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/zcode-server
    cp -a source/. $out/libexec/zcode-server/
    chmod -R u+w $out/libexec/zcode-server
    # The archive ships no provider table: the desktop hands the path over in
    # ZCODE_BUILTIN_PROVIDER_CONFIG_FILE when it spawns the server. Standalone
    # runs need it on disk, at the sibling `provider/` the CLI probes.
    ln -s ${zcode-cli}/share/zcode-cli/glm/provider $out/libexec/zcode-server/runtime/provider
    makeWrapper $out/libexec/zcode-server/bin/zcode $out/bin/zcode-server
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    local output
    output=$($out/bin/zcode-server --version 2>/dev/null | tail -1)
    [ -n "$output" ] || {
      echo "zcode-server --version produced no output" >&2
      exit 1
    }
    echo "zcode-server version: $output"
    runHook postInstallCheck
  '';

  meta = {
    description = "Headless ZCode Source Server (the runtime the desktop installs over SSH)";
    homepage = "https://zcode.z.ai/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
    mainProgram = "zcode-server";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
