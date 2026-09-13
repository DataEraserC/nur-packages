{
  fetchFromGitHub,
  lib,
  buildNpmPackage,
  nodejs_24,
}:
buildNpmPackage (finalAttrs: {
  pname = "cliproxyapi-management-center";
  version = "1.22.18";
  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "Cli-Proxy-API-Management-Center";
    tag = "v${finalAttrs.version}";
    hash = "sha256-VOAap+/z5ebooUQwK2D5xjRY14gHCEj/RwL/DB33e88=";
  };

  nodejs = nodejs_24;
  npmDepsHash = "sha256-w0zcVuhU7mW11dLXbAEwBorgXl7woNIHeSknjJ1I5yc=";

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
    maintainers = with lib.maintainers; [ xddxdd ];
    platforms = lib.platforms.all;
  };
})
