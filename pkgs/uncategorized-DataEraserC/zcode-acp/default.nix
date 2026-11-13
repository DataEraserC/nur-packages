{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  jq,
  pnpm_10,
  pnpmConfigHook,
  python3,
  nodejs_24,
  makeWrapper,
  zcode-cli,
  nix-update-script,
  versionCheckHook,
}:
let
  version = "0.84.3";

  src = fetchFromGitHub {
    owner = "william0wang";
    repo = "zcode-acp";
    tag = "v${version}";
    hash = "sha256-Ifwj2sboxPM/SjnRbUXjN5hR/5VOb+JKWLtoyAfWf3k=";
  };

  pnpmDeps = fetchPnpmDeps {
    pname = "zcode-acp-pnpm-deps";
    inherit version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-zxRcsWFuufPpv/S+ruHHNxcLwhVrWzXxIzQaNQQ0bhQ=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "zcode-acp";
  inherit version src;
  __structuredAttrs = true;
  strictDeps = true;

  pnpmDeps = pnpmDeps;

  nativeBuildInputs = [
    jq
    (python3.withPackages (ps: [ ps.pyyaml ]))
    nodejs_24
    pnpm_10
    pnpmConfigHook
    makeWrapper
    zcode-cli
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall
        # dist imports zod at runtime, but upstream declares it a peerDependency
        # for editor-plugin reuse; pnpm drops peers on --prod installs, so promote
        # it to a regular dependency in package.json and in the lockfile importer
        # (keeping them consistent for --frozen-lockfile), then reinstall a clean
        # production node_modules from the same resolutions.
        jq '.dependencies.zod = .devDependencies.zod | del(.peerDependencies) | del(.devDependencies)' \
          package.json > package.json.tmp
        mv package.json.tmp package.json
        python3 <<'EOF'
    import yaml

    with open("pnpm-lock.yaml") as f:
        d = yaml.safe_load(f)
    imp = d["importers"]["."]
    if "zod" not in imp["dependencies"]:
        z = imp.get("devDependencies", {}).get("zod") or imp.get("peerDependencies", {}).get("zod")
        assert z, "zod not found in lockfile importer"
        imp["dependencies"]["zod"] = z
    imp.pop("peerDependencies", None)
    imp.pop("devDependencies", None)
    with open("pnpm-lock.yaml", "w") as f:
        yaml.safe_dump(d, f, sort_keys=False, default_flow_style=False, width=1000000000)
    EOF
        rm -rf node_modules
        pnpm install --frozen-lockfile --prod --offline
        mkdir -p $out/share/zcode-acp $out/bin
        cp -a dist assets node_modules package.json $out/share/zcode-acp/
        makeWrapper ${lib.getExe nodejs_24} $out/bin/zcode-acp-server \
          --add-flags "$out/share/zcode-acp/dist/cli.js" \
          --set ZCODE_BIN ${lib.getExe zcode-cli} \
          --set NODE_ENV production
        ln -s zcode-acp-server $out/bin/zcode-acp
        runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--version";

  postInstallCheck = ''
    local response
    response=$(printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{"fs":{"readTextFile":true,"writeTextFile":true}}}}' \
      | $out/bin/zcode-acp-server 2>/dev/null || true)
    case $response in
      *'"agentInfo"'*) echo "zcode-acp ACP initialize handshake ok" ;;
      *)
        echo "zcode-acp ACP initialize handshake failed, got: $response" >&2
        exit 1
        ;;
    esac
  '';

  passthru = {
    updateScript = nix-update-script { };
    inherit pnpmDeps;
  };

  meta = {
    changelog = "https://github.com/william0wang/zcode-acp/releases";
    description = "Agent Client Protocol bridge for the headless ZCode coding agent";
    homepage = "https://github.com/william0wang/zcode-acp";
    license = lib.licenses.asl20;
    maintainers = import ../maintainers.nix;
    mainProgram = "zcode-acp-server";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
