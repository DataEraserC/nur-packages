# https://github.com/NixOS/nixpkgs/blob/nixos-24.11/pkgs/by-name/hd/hdrop/package.nix#L51
{
  coreutils,
  gawk,
  hyprland,
  jq,
  lib,
  libnotify,
  makeWrapper,
  scdoc,
  stdenvNoCC,
  util-linux,
  withHyprland ? true,
  sources,
  ...
}:
stdenvNoCC.mkDerivation {
  inherit (sources.AAA_hdrop) pname version src;

  nativeBuildInputs = [
    makeWrapper
    scdoc
  ];

  makeFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    wrapProgram $out/bin/hdrop --prefix PATH ':' \
      "${
        lib.makeBinPath (
          [
            coreutils
            util-linux
            jq
            libnotify
            gawk
          ]
          ++ lib.optional withHyprland hyprland
        )
      }"
  '';

  meta = with lib; {
    description = "Emulate 'tdrop' in Hyprland (run, show and hide specific programs per keybind)";
    homepage = "https://github.com/Schweber/hdrop";
    changelog = "https://github.com/Schweber/hdrop/releases/tag/v${version}";
    license = licenses.agpl3Only;
    platforms = platforms.linux;
    maintainers = with maintainers; [ Schweber ];
    mainProgram = "hdrop";
  };
}
