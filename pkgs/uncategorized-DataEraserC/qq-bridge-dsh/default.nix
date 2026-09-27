{
  lib,
  stdenv,
  pkgs,
  nodejs,
  # Runtime path to qq-bridge data directory (config.json, state/).
  # Override via: pkgs.qq-bridge-dsh.override { qqBridgeHome = "/custom/path"; }
  qqBridgeHome ? "~/.local/share/qq-bridge",
  # Extra entries admitted by the presets' execution-time tool guard
  # (qq-tool-restrict.mjs). Entries ending in "__" extend the MCP namespace
  # prefix whitelist (SAFE_PREFIXES); all others extend the exact-name set
  # (SAFE_EXACT). Known-dangerous global tools stay denied regardless.
  # Override via: pkgs.qq-bridge-dsh.override { extraAllowedTools = [ ... ]; }
  extraAllowedTools ? [ ],
  python3,
}:

let
  unwrapped = pkgs.callPackage ../qq-bridge-unwrapped { };
  inherit (unwrapped) version;
  node = "${nodejs}/bin/node";

  # Patched unwrapped: copy the full package tree, patch ROOT in MCP servers
  # so they read config from $QQ_BRIDGE_HOME instead of the read-only store.
  patchedUnwrapped = unwrapped.overrideAttrs (old: {
    pname = "${old.pname}-patched";
    postInstall = (old.postInstall or "") + ''
      srcDir="$out/lib/node_modules/qq-bridge/src"
      chmod -R u+w "$srcDir"
      for f in mcp-snowluma-safe.js mcp-host-server.js; do
        substituteInPlace "$srcDir/$f" \
          --replace 'const ROOT = path.resolve(__dirname, '"'"'..'"'"');' \
                    'const ROOT = process.env.QQ_BRIDGE_HOME || path.resolve(__dirname, '"'"'..'"'"');'
      done
    '';
  });
  patchedSrc = "${patchedUnwrapped}/lib/node_modules/qq-bridge";

  # Appended to every preset's qq-tool-restrict.mjs at build time. The block
  # runs at module load (after the whitelist consts): "__"-suffixed entries
  # join SAFE_PREFIXES, others join SAFE_EXACT, and names in
  # KNOWN_DANGEROUS_GLOBAL_TOOLS are skipped so the deny layer stays absolute.
  extraToolsSnippet = lib.optionalString (extraAllowedTools != [ ]) ''
    # ── nix override: extraAllowedTools（构建期注入，勿手工编辑） ──
    for f in "$presetDir"/*/qq-tool-restrict.mjs; do
      [ -e "$f" ] || continue
      chmod u+w "$f"
      cat >> "$f" <<'QQ_TOOL_EXTRA'

    // ── nix override: extraAllowedTools（构建期注入，勿手工编辑） ──
    for (const t of ${builtins.toJSON extraAllowedTools}) {
      if (typeof t !== 'string' || t.length === 0) continue
      if (KNOWN_DANGEROUS_GLOBAL_TOOLS.includes(t)) continue
      if (t.endsWith('__')) {
        if (!SAFE_PREFIXES.includes(t)) SAFE_PREFIXES.push(t)
      } else {
        SAFE_EXACT.add(t)
      }
    }
    QQ_TOOL_EXTRA
    done
  '';
in
stdenv.mkDerivation {
  pname = "qq-bridge-dsh";
  inherit version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    pkgDir=$out/lib/node_modules/qq-bridge-dsh
    mkdir -p $pkgDir

    # ── Full patched package (src + node_modules + all dependencies) ──
    cp -r ${patchedSrc}/* $pkgDir/
    chmod -R u+w $pkgDir

    # ── DSH bundle package.json (must override unwrapped's) ──
    cp ${./package.json} $pkgDir/package.json
    substituteInPlace $pkgDir/package.json \
      --replace '@VERSION@' '${version}'

    # ── Preset files: source of truth for the generated preset rows ──
    presetDir=$out/share/qq-bridge-presets
    mkdir -p $presetDir
    cp -r ${patchedSrc}/dsh/agent-presets/* $presetDir/
    ${extraToolsSnippet}

    # ── cordis.patch.yml: substitute paths, then generate preset rows ──
    cp ${./cordis.patch.yml} $pkgDir/cordis.patch.yml
    substituteInPlace $pkgDir/cordis.patch.yml \
      --replace '@NODE@' '${node}' \
      --replace '@PKGDIR@' "$pkgDir" \
      --replace '@QQ_BRIDGE_HOME@' '${qqBridgeHome}'
    ${python3}/bin/python3 ${./generate-preset-rows.py} "$presetDir" "$pkgDir/cordis.patch.yml"

    # ── qq-mode-console plugin ──
    pluginDir=$pkgDir/plugins/qq-mode-console
    mkdir -p $pluginDir
    cp -r ${patchedSrc}/plugins/qq-mode-console/* $pluginDir/

    # ── DSH bundle metadata ──
    mkdir -p $out/nix-support
    substitute ${./dsh-bundles.json} $out/nix-support/dsh-bundles.json \
      --replace '@VERSION@' '${version}' \
      --replace '@PKGDIR@' "$pkgDir"

    runHook postInstall
  '';

  passthru = {
    inherit
      unwrapped
      patchedUnwrapped
      qqBridgeHome
      extraAllowedTools
      ;
    dshBundle = true;
    dshBundleHelper = "buildDshBundle";
    runtimeDeps = [ ];
    aiProvenance = [
      {
        agent = "dsh";
        model = "mimo-v2.5-free";
        involvement = "assisted";
      }
      {
        agent = "dsh";
        model = "mimo-v2.6-flash-free";
        involvement = "authored";
      }
    ];
  };

  meta = {
    description = "DSH bundle for qq-bridge: MCP servers and agent presets";
    homepage = "https://github.com/Derpyu520/qq-bridge";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.unix;
  };
}
