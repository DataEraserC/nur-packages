{
  lib,
  stdenv,
  nodejs,
  qq-bridge-unwrapped,
  nix-update-script,
}:

let
  inherit (qq-bridge-unwrapped) version;
  node = "${nodejs}/bin/node";
  src = "${qq-bridge-unwrapped}/lib/node_modules/qq-bridge";
in
stdenv.mkDerivation {
  pname = "qq-bridge-dsh";
  inherit version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    pkgDir=$out/lib/node_modules/qq-bridge-dsh
    mkdir -p $pkgDir

    # ── package.json ──
    cat > $pkgDir/package.json << 'EOF'
    {
      "name": "qq-bridge-dsh",
      "private": true,
      "dsh": {
        "bundle": {
          "patch": "./cordis.patch.yml"
        }
      }
    }
    EOF

    # ── cordis.patch.yml ──
    # Registers 3 MCP servers that point to qq-bridge's source scripts.
    # DSH resolves Node.js deps (node_modules) relative to the script,
    # so pointing at the unwrapped package's src/ works.
    cat > $pkgDir/cordis.patch.yml << CORDIS
    # qq-bridge DSH bundle: MCP servers for QQ ↔ DSH bridge.
    # Scripts live in the qq-bridge-unwrapped package; DSH resolves
    # node_modules relative to the script path.
    - insert:
        - id: mcp-snowluma
          name: '@deepseek-ai/dsh-mcp-client'
          config:
            serverName: snowluma
            transport: stdio
            command: ${node}
            args:
              - ${src}/src/mcp-snowluma-safe.js
            toolCallTimeoutMs: 725000
        - id: mcp-snowluma-host
          name: '@deepseek-ai/dsh-mcp-client'
          config:
            serverName: snowluma-host
            transport: stdio
            command: ${node}
            args:
              - ${src}/src/mcp-host-server.js
        - id: mcp-web-search-safe
          name: '@deepseek-ai/dsh-mcp-client'
          config:
            serverName: web-search-safe
            transport: stdio
            command: ${node}
            args:
              - ${src}/src/mcp-web-search-safe.js
    CORDIS

    # ── Preset files ──
    # Copy qq-chat and qq-chat-v2 agent presets so DSH can discover them.
    presetDir=$out/share/qq-bridge-presets
    mkdir -p $presetDir
    cp -r ${src}/dsh/agent-presets/* $presetDir/

    # ── qq-mode-console plugin ──
    pluginDir=$pkgDir/plugins/qq-mode-console
    mkdir -p $pluginDir
    cp -r ${src}/plugins/qq-mode-console/* $pluginDir/

    runHook postInstall
  '';

  passthru = {
    inherit (qq-bridge-unwrapped) unwrapped;
    updateScript = nix-update-script {
      attrPath = "qq-bridge-dsh";
      extraArgs = [ "--flake" ];
    };
  };

  meta = {
    description = "DSH bundle for qq-bridge: MCP servers and agent presets";
    homepage = "https://github.com/Derpyu520/qq-bridge";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.unix;
  };
}
