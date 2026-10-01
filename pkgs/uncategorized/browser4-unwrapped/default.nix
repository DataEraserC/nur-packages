{
  alsa-lib,
  autoPatchelfHook,
  cacert,
  fetchFromGitHub,
  fetchurl,
  lib,
  libX11,
  libXext,
  libXi,
  libXrender,
  libXtst,
  rustPlatform,
  stdenv,
  versionCheckHook,
}:
let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  tag = sources.browser4.tag;
  assetName = sources.runtime.assetName;
  installedAt = "1970-01-01T00:00:00+00:00";

  repoSource = fetchFromGitHub {
    owner = "platonai";
    repo = "Browser4";
    inherit tag;
    hash = sources.browser4.hash;
  };

  runtime = stdenv.mkDerivation (finalAttrs: {
    pname = "browser4-runtime";
    inherit (sources.runtime) version;
    src = fetchurl {
      inherit (sources.runtime) url hash;
    };

    sourceRoot = ".";
    dontStrip = true;

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [
      alsa-lib
      libX11
      libXext
      libXi
      libXrender
      libXtst
    ];

    installPhase = ''
      runHook preInstall

      installDir=$out/share/browser4/runtime/${tag}
      mkdir -p "$installDir"
      cp -r bin lib runtime "$installDir"/
      cp -r ${repoSource}/skills "$installDir"/skills
      printf '%s' '${
        builtins.toJSON {
          inherit tag;
          asset_name = assetName;
          download_url = sources.runtime.url;
          installed_at = installedAt;
        }
      }' > "$installDir/browser4-installation.json"
      printf '%s\n' "${tag}" > "$out/share/browser4/runtime/current.tag"

      runHook postInstall
    '';

    preFixup = ''
      addAutoPatchelfSearchPath "$out/share/browser4/runtime/${tag}/runtime/lib"
      addAutoPatchelfSearchPath "$out/share/browser4/runtime/${tag}/runtime/lib/server"
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      "$out/share/browser4/runtime/${tag}/runtime/bin/java" -version
      runHook postInstallCheck
    '';
  });

  browser4 = rustPlatform.buildRustPackage (finalAttrs: {
    pname = "browser4-unwrapped";
    inherit (sources.browser4) version;
    src = repoSource;

    cargoRoot = "cli/browser4-cli";
    buildAndTestSubdir = "cli/browser4-cli";
    cargoLock = {
      lockFile = ./Cargo.lock;
    };
    cargoTestFlags = [ "--bins" ];

    preCheck = ''
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    '';

    postPatch = ''
      printf '\n#[cfg(not(windows))]\nfn windows_powershell_candidates() -> Vec<String> {\n    Vec::new()\n}\n' >> cli/browser4-cli/src/main.rs
    '';

    nativeInstallCheckInputs = [ versionCheckHook ];
    doInstallCheck = true;
    versionCheckProgramArg = "--version";

    passthru = {
      inherit runtime tag;
    };

    meta = {
      description = "MCP-driven browser automation toolkit pairing a Rust command-line client with a Java automation server (unwrapped)";
      homepage = "https://github.com/platonai/Browser4";
      changelog = "https://github.com/platonai/Browser4/releases";
      license = lib.licenses.asl20;
      maintainers = with lib.maintainers; [ xddxdd ];
      mainProgram = "browser4-cli";
      platforms = [ "x86_64-linux" ];
    };
  });
in
browser4
