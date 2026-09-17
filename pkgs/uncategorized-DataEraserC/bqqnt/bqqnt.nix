{
  callPackage,
  makeWrapper,
  symlinkJoin,
  pkgs,
  bstar ? callPackage ./../bstar { },
}:
let
  inherit (pkgs) qq;
in
symlinkJoin {
  pname = "bqqnt";
  inherit (bstar) version;

  paths = [ qq ];

  nativeBuildInputs = [ makeWrapper ];

  postBuild = ''
    makeWrapper ${qq}/bin/qq $out/bin/bqqnt \
      --set LD_PRELOAD "${bstar}/lib/libbstar.so"

    cp ${qq}/share/applications/qq.desktop $out/share/applications/qq2.desktop
    sed -i \
      -e "s|^Exec=[^ ]*|Exec=$out/bin/bqqnt|" \
      -e "s|^Name=.*$|Name=bqqnt|" \
      $out/share/applications/qq2.desktop
  '';

  passthru.aiProvenance = [
    {
      agent = "dsh";
      model = "deepseek-v4-flash";
      involvement = "assisted";
    }
  ];

  meta = qq.meta // {
    description = "Desktop client for QQ on Linux with bstar";
    platforms = [ "x86_64-linux" ];
    maintainers = import ../maintainers.nix;
    mainProgram = "bqqnt";
  };
}
