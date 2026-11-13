{ callPackage, ... }:
(callPackage ../qoder-common.nix { }) {
  pname = "qoder-ide";
  version = "1.39.2-1794211870";
  url = "https://download.qoder.com/release/latest/qoder-ide_amd64.deb";
  hash = "sha256-2eSG78ACLGApOntjyFLyA7bYCW8DNCKn3jJ4VR3BM8M=";
  appDir = "qoder-ide";
  executable = "qoder-ide";
  desktopName = "qoder-ide.desktop";
  iconName = "qoder-ide";
  mainProgram = "qoder-ide";
  description = "Qoder IDE, Alibaba's agentic coding platform (international edition)";
  homepage = "https://qoder.com/";
  updateScript = ./update.sh;
}
