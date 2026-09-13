{
  fetchFromGitHub,
  lib,
  buildNpmPackage,
  nodejs_24,
}:
buildNpmPackage (finalAttrs: {
  pname = "cliproxyapi-management-center";
  version = "1.23.0";
  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "Cli-Proxy-API-Management-Center";
    tag = "v${finalAttrs.version}";
    hash = "sha256-sSTQB3Ase18cXigx4IWOCNPE6sonGwoI0GILw9l/VW8=";
  };

  nodejs = nodejs_24;
  npmDepsHash = "sha256-Gp4w4idXv/iACyIAuw5VK8SqS2ZV/gQMPZHXPvn8KZY=";

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
