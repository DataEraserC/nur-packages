{
  stdenv,
  callPackage,
  qq,
  runtimeShell,
  qq-original ? qq,
  bstar ? callPackage ./../bstar { },
}:
# https://github.com/Anillc/chronocat.nix/blob/979b76c49df44490978e032c1df74af5e09b72c1/modules/bstar.nix
stdenv.mkDerivation {
  name = "bstar";
  buildInputs = [
    stdenv.cc.cc.lib
    bstar
  ];
  nativeBuildInputs = [
    # autoPatchelfHook
  ];
  unpackPhase = ":";
  installPhase = ''
    mkdir -p $out/{lib,bin}
    cp -r ${qq-original}/share $out
    cat > $out/bin/bqqnt <<EOF
    #!${runtimeShell}
    LD_PRELOAD=${bstar}/lib/libbstar.so BQQNT_CC=1 exec ${qq-original}/bin/qq \$@
    EOF
    chmod +x $out/bin/bqqnt
  '';
  postInstall = ''
    sed -i $out/share/applications/qq.desktop \
      -e "s|^Exec=.*$|Exec=bqqnt|"
  '';
  meta = qq-original.meta // {
    mainProgram = "bqqnt";
  };
}
