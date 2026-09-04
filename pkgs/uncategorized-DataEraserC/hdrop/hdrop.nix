# https://github.com/NixOS/nixpkgs/blob/nixos-24.11/pkgs/by-name/hd/hdrop/package.nix#L51
{
  fetchFromGitHub,
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
  unstableGitUpdater,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "hdrop";
  version = "0.7.9-unstable-2026-02-17";

  src = fetchFromGitHub {
    owner = "Schweber";
    repo = "hdrop";
    rev = "ae05f71230ee57ec520cb8c9317d7240149488bb";
    hash = "sha256-YwDYMABJOeo32wCvSjWdIY1l3C4oLMPdHy5UDHNkwx8=";
    fetchSubmodules = true;
  };

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/Schweber/hdrop.git";
    tagPrefix = "v";
  };

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
