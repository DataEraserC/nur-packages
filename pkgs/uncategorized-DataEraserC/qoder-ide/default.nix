{ callPackage, ... }:
(callPackage ../qoder-common.nix { }) {
  pname = "qoder-ide";
  version = "1.41.1-1795077337";
  url = "https://download.qoder.com/release/latest/qoder-ide_amd64.deb";
  hash = "sha256-+BTowlsEepTnaQaxXCCZlrF5x4oG3DmAg/6w+xDAlzQ=";
  appDir = "qoder-ide";
  executable = "qoder-ide";
  desktopName = "qoder-ide.desktop";
  iconName = "qoder-ide";
  mainProgram = "qoder-ide";
  description = "Qoder IDE, Alibaba's agentic coding platform (international edition)";
  homepage = "https://qoder.com/";
  updateScript = ./update.sh;
}
