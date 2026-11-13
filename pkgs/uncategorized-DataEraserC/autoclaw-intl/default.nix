{ callPackage, ... }:
(callPackage ../autoclaw-common.nix { }) {
  pname = "autoclaw-intl";
  version = "2.0.3";
  url = "https://autoglm-public-oss.z.ai/zwork/updates/production/official/linux-x64/AutoClaw-2.0.3-x64.AppImage";
  hash = "sha512-T1Uc6EcPmCcHGwH64rU+tTzGWwyjcc/QHlGvI37E6ifhww1i7pVYFiQw5tIzRl+WgwZ8YmY9BNLOzT72T0JM1A==";
  desktopFile = "AutoClaw2.desktop";
  iconFile = "usr/share/icons/hicolor/512x512/apps/AutoClaw2.png";
  mainProgram = "autoclaw-intl";
  xdgDir = "autoclaw-intl";
  description = "AutoClaw, Z.ai's general AI agent desktop app (international edition)";
  homepage = "https://autoclaw.z.ai/";
  updateScript = ./update.sh;
}
