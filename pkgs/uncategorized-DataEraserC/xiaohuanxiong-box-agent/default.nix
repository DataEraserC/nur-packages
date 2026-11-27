{
  lib,
  stdenv,
  dpkg,
  patchelf,
  zlib,
  xiaohuanxiong,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "xiaohuanxiong-box-agent";
  inherit (xiaohuanxiong) version src;

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs = [
    dpkg
    patchelf
  ];

  dontStrip = true;
  dontPatchELF = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec
    cp -r "opt/商汤小浣熊/resources/box-agent-runtime" $out/libexec/box-agent-runtime
    chmod -R u+w $out/libexec/box-agent-runtime

    patchelf \
      --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
      --replace-needed libz.so.1 ${lib.getLib zlib}/lib/libz.so.1 \
      --replace-needed libc.so.6 ${lib.getLib stdenv.cc.libc}/lib/libc.so.6 \
      --replace-needed libdl.so.2 ${lib.getLib stdenv.cc.libc}/lib/libdl.so.2 \
      --replace-needed libpthread.so.0 ${lib.getLib stdenv.cc.libc}/lib/libpthread.so.0 \
      "$out/libexec/box-agent-runtime/bin/box-agent-acp"

    runHook postInstall
  '';

  passthru = {
    inherit (xiaohuanxiong) version;
    runtimeDir = "${placeholder "out"}/libexec/box-agent-runtime";
  };

  meta = {
    description = "Box-Agent runtime extracted from the Raccoon Work desktop client";
    homepage = "https://xiaohuanxiong.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
