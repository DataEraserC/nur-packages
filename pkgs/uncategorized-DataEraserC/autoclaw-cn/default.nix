{ callPackage, ... }:
(callPackage ../autoclaw-common.nix { }) {
  pname = "autoclaw-cn";
  version = "4.0.0";
  url = "https://autoglm.aminer.cn/zwork/updates/production/official/linux-x64/AutoClaw-4.0.0-x64-cn.AppImage";
  hash = "sha512-eVz4K6V20e6yiSC4w/dABeSgGutYrMvhFb8QGwnb22TYiLxf94c3MDa3ojZbHxawT8WdIU5CtlfzmgU2ej8RFQ==";
  desktopFile = "AutoClaw2.desktop";
  iconFile = "usr/share/icons/hicolor/512x512/apps/AutoClaw2.png";
  mainProgram = "autoclaw-cn";
  xdgDir = "autoclaw-cn";
  description = "AutoClaw (澳龙), Zhipu AI's general AI agent desktop app (China edition)";
  homepage = "https://autoclaw.zhipuai.cn/";
  updateScript = ./update.sh;
}
