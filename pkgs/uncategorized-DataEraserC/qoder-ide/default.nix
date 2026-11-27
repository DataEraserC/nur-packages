{ callPackage, ... }:
(callPackage ../qoder-common.nix { }) {
  pname = "qoder-ide";
  version = "1.42.1-1795778934";
  url = "https://download.qoder.com/release/latest/qoder-ide_amd64.deb";
  hash = "sha256-6/QKE4cFxh1KvFJfT5zsnCuvRY1yCNkgkxKl6zrcYKI=";
  appDir = "qoder-ide";
  executable = "qoder-ide";
  desktopName = "qoder-ide.desktop";
  iconName = "qoder-ide";
  mainProgram = "qoder-ide";
  description = "Qoder IDE, Alibaba's agentic coding platform (international edition)";
  homepage = "https://qoder.com/";
  updateScript = ./update.sh;
}
