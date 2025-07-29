{
  stdenv,
  callPackage,
  runtimeShell,
  autoPatchelfHook,
  qq,
  qq-original ? qq,
  bstar ? callPackage ./../bstar { },
}:
# https://github.com/Anillc/chronocat.nix/blob/979b76c49df44490978e032c1df74af5e09b72c1/modules/bstar.nix
stdenv.mkDerivation {
  name = "bqqnt";
  inherit (bstar) version;
  buildInputs = [
    stdenv.cc.cc.lib
    bstar
  ];
  nativeBuildInputs = [
    autoPatchelfHook
  ];
  unpackPhase = ":";
  installPhase = ''
    mkdir -p $out/{lib,bin}

    cp -r ${qq-original}/share $out

    chmod 755 -R $out

    cat $out/share/applications/qq.desktop > $out/share/applications/qq2.desktop

    sed -i $out/share/applications/qq2.desktop \
      -e "s|^Exec=.*$|Exec=bqqnt|" \
      -e "s|^Name=.*$|Name=bqqnt|"

    cat > $out/bin/qq <<EOF
    #!${runtimeShell}
    exec ${qq-original}/bin/qq \$@
    EOF

    cat > $out/bin/bqqnt <<EOF
    #!${runtimeShell}
    LD_PRELOAD=${bstar}/lib/libbstar.so exec ${qq-original}/bin/qq \$@
    EOF

    chmod +x $out/bin/qq $out/bin/bqqnt
  '';
  postInstall = '''';
  meta = qq-original.meta // {
    mainProgram = "bqqnt";
  };
}
