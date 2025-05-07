# https://github.com/NixOS/nixpkgs/blob/nixos-24.11/pkgs/by-name/hd/hdrop/package.nix#L51
{
  coreutils,
  gawk,
  niri,
  jq,
  lib,
  libnotify,
  makeWrapper,
  scdoc,
  stdenvNoCC,
  util-linux,
  withNiri ? true,
  sources,
  ...
}:
stdenvNoCC.mkDerivation {
  inherit (sources.ndrop) pname version src;

  nativeBuildInputs = [
    makeWrapper
    scdoc
  ];

  makeFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    wrapProgram $out/bin/ndrop --prefix PATH ':' \
      "${
        lib.makeBinPath (
          [
            coreutils
            util-linux
            jq
            libnotify
            gawk
          ]
          ++ lib.optional withNiri niri
        )
      }"
  '';

  meta = with lib; {
    description = "Emulate 'tdrop' in Hyprland (run, show and hide specific programs per keybind)";
    homepage = "https://github.com/Schweber/ndrop";
    changelog = "https://github.com/Schweber/ndrop/releases/tag/v${version}";
    license = licenses.agpl3Only;
    platforms = platforms.linux;
    maintainers = with maintainers; [ Schweber ];
    mainProgram = "ndrop";
  };
}
