# https://github.com/NixOS/nixpkgs/blob/nixos-24.11/pkgs/by-name/hd/hdrop/package.nix#L51
{
  fetchFromGitHub,
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
  unstableGitUpdater,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "ndrop";
  version = "unstable-2026-01-25";

  src = fetchFromGitHub {
    owner = "Schweber";
    repo = "ndrop";
    rev = "f2fb1c611811c48b48cd0f0fecab4f3f935e7405";
    hash = "sha256-/Xco1sr76+F3mAIGq29yp5Y6FPcXS/AVXDpwZ1+rLQk=";
    fetchSubmodules = true;
  };

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/Schweber/ndrop.git";
  };

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
    description = "Emulate 'tdrop' in niri (run, show and hide programs via keybind - similar to a dropdown terminal)";
    homepage = "https://github.com/Schweber/ndrop";
    changelog = "https://github.com/Schweber/ndrop/releases/tag/v${version}";
    license = licenses.agpl3Only;
    platforms = platforms.linux;
    maintainers = with maintainers; [ Schweber ];
    mainProgram = "ndrop";
  };
}
