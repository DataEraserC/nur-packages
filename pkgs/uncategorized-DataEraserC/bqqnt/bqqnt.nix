{
  stdenv,
  callPackage,
  makeWrapper,
  qq,
  qq-original ? qq,
  bstar ? callPackage ./../bstar { },
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "bqqnt";
  inherit (bstar) version;

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cp -r ${qq-original}/share $out
    chmod 755 -R $out

    makeWrapper ${qq-original}/bin/qq $out/bin/qq \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}"

    makeWrapper $out/bin/qq $out/bin/bqqnt \
      --set LD_PRELOAD "${bstar}/lib/libbstar.so"

    cp $out/share/applications/qq.desktop $out/share/applications/qq2.desktop

    sed -i -e "s|^Exec=.*$|Exec=$out/bin/qq|" $out/share/applications/qq.desktop
    sed -i \
      -e "s|^Exec=.*$|Exec=$out/bin/bqqnt|" \
      -e "s|^Name=.*$|Name=bqqnt|" \
      $out/share/applications/qq2.desktop

    runHook postInstall
  '';

  passthru.aiProvenance = [
    {
      agent = "dsh";
      model = "deepseek-v4-flash";
      involvement = "assisted";
    }
  ];

  meta = qq-original.meta // {
    maintainers = import ../maintainers.nix;
    mainProgram = "bqqnt";
  };
})
