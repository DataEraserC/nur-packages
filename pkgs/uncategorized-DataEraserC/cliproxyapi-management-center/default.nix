{
  fetchFromGitHub,
  lib,
  buildNpmPackage,
  nodejs_24,
}:
buildNpmPackage (finalAttrs: {
  pname = "cliproxyapi-management-center";
  version = "1.29.0";
  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "Cli-Proxy-API-Management-Center";
    tag = "v${finalAttrs.version}";
    hash = "sha256-swvEn6M+mmYb2595QjwvdqPvTTStldf7WDgyAdrWU3g=";
  };

  nodejs = nodejs_24;
  npmDepsHash = "sha256-ANt85irjAqxs0DYlQKQ/wr0RE2cPDryTkBXuddT18cc=";

  env.VERSION = finalAttrs.version;

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r dist/. $out/
    ln -s index.html $out/management.html

    runHook postInstall
  '';

  passthru.updateScript = [ (toString ./update.sh) ];

  meta = {
    description = "Web management interface for CLIProxyAPI";
    homepage = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.all;
  };
})
