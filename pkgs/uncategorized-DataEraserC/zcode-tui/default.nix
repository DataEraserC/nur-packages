# The TUI bundle that zcode.cjs imports as @zcode/tui.
#
# The desktop AppImage only ships the CLI shell; the TUI sources live in the
# server archive (runtime/node_modules/@zcode/tui) without a dist/ output.
# Build that workspace package with esbuild and keep the runtime node_modules
# around so its external imports (opentui, react, shiki, …) resolve.
{
  lib,
  stdenv,
  fetchurl,
  esbuild,
  autoPatchelfHook,
}:

let
  sources = import ../zcode-server/sources.nix;
  inherit (stdenv.hostPlatform) system;
  asset = sources.assets.${system} or (throw "zcode-tui: no release for ${system}");
in
stdenv.mkDerivation {
  pname = "zcode-tui";
  inherit (sources) version;

  src = fetchurl {
    url = "https://cdn-zcode.z.ai/zcode/electron/releases/${sources.version}/${asset.name}";
    inherit (asset) sha256;
  };

  nativeBuildInputs = [
    esbuild
    autoPatchelfHook
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    stdenv.cc.libc
  ];

  dontConfigure = true;
  dontFixup = false;

  unpackPhase = ''
    runHook preUnpack
    mkdir -p source
    tar -xzf $src -C source --strip-components=1
    runHook postUnpack
  '';

  buildPhase = ''
    runHook preBuild
    mkdir -p dist
    esbuild source/runtime/node_modules/@zcode/tui/src/index.ts \
      --bundle \
      --outfile=dist/index.js \
      --format=esm \
      --platform=node \
      --target=node22 \
      --log-level=warning \
      --external:@mbears/opentui-core \
      --external:@mbears/opentui-react \
      --external:react \
      --external:react-devtools-core \
      --external:shiki \
      --external:web-tree-sitter \
      --external:ws
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib
    cp -a source/runtime/node_modules $out/lib/node_modules
    chmod -R u+w $out/lib/node_modules

    mkdir -p $out/lib/node_modules/@zcode/tui/dist
    cp dist/index.js $out/lib/node_modules/@zcode/tui/dist/index.js
    # The TUI package is consumed only through dist/; drop build-only trees.
    rm -rf $out/lib/node_modules/@zcode/tui/tests \
      $out/lib/node_modules/@zcode/tui/scripts \
      $out/lib/node_modules/@zcode/tui/tsconfig.json
    runHook postInstall
  '';

  # Some node_modules entries ship prebuilt .node files.
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libc.musl-aarch64.so.1"
  ];

  meta = {
    description = "TUI workspace bundle used by the ZCode CLI";
    homepage = "https://zcode.z.ai/";
    license = lib.licenses.asl2;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
