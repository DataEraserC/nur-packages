{ callPackage, ... }:
(callPackage ../qoder-app-common.nix { }) {
  pname = "qoder-cn";
  version = "0.5.20";
  url = "https://qoder-app.oss-cn-beijing.aliyuncs.com/qoder-app/releases/latest/Qoder-CN-linux-amd64.deb";
  hash = "sha256-rF49uLWtjDrg74RJ8fAw02YLWr73SX1xZqoBGIuCWg8=";
  appDir = "Qoder-CN";
  executable = "qoder-cn";
  desktopName = "qoder-cn.desktop";
  mainProgram = "qoder-cn";
  description = "Qoder CN App, Alibaba's agent workbench for human and AI software teams (China edition)";
  homepage = "https://qoder.com.cn/";
  updateScript = ./update.sh;
}
