{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  jq,
}:

buildNpmPackage (finalAttrs: {
  pname = "dsh-bas-remote";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "DataEraserC";
    repo = "dsh-bas-remote";
    rev = "e9131de9b23ff92ec421b955a88b330c01128347";
    hash = "sha256-xqVWvf5Bv/mZaQnz1n2MPtrX44kVX2lqSrZkg/10H5Q=";
  };

  npmDepsHash = "sha256-wlmJvOnnHIxuOt8KlSieu2hWeNsi6ykLgm7ni1FQaWk=";

  npmFlags = [ "--legacy-peer-deps" ];

  dontNpmBuild = true;

  nativeBuildInputs = [
    jq
  ];

  postInstall = ''
    bundleRoot="$out/lib/node_modules"
    [ -d "$bundleRoot" ] || {
      printf 'dsh-bas-remote: expected bundle output directory %s\n' "$bundleRoot" >&2
      exit 1
    }

    pkgRoot="$bundleRoot/dsh-bas-remote"
    [ -d "$pkgRoot" ] || {
      printf 'dsh-bas-remote: expected package directory %s\n' "$pkgRoot" >&2
      exit 1
    }

    [ -f "$pkgRoot/lib/index.js" ] || {
      printf 'dsh-bas-remote: host entry lib/index.js is missing\n' >&2
      exit 1
    }

    [ -f "$pkgRoot/lib/client.js" ] || {
      printf 'dsh-bas-remote: client entry lib/client.js is missing\n' >&2
      exit 1
    }

    [ -f "$pkgRoot/cordis.patch.yml" ] || {
      printf 'dsh-bas-remote: cordis.patch.yml is missing\n' >&2
      exit 1
    }

    mkdir -p "$out/nix-support"
    jq -n \
      --arg name "dsh-bas-remote" \
      --arg version "${finalAttrs.version}" \
      --arg patch "./cordis.patch.yml" \
      --arg packageRoot "$pkgRoot" \
      '{ schema: 1, bundles: [{ name: $name, version: $version, patch: $patch, packageRoot: $packageRoot }] }' \
      > "$out/nix-support/dsh-bundles.json"
  '';

  passthru = {
    dshBundle = true;
    dshBundleHelper = "buildDshBundle";
    runtimeDeps = [ ];
  };

  meta = {
    description = "SAP Business Application Studio remote dev spaces for DeepSeek Harness";
    homepage = "https://github.com/DataEraserC/dsh-bas-remote";
    license = lib.licenses.asl20;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.unix;
  };
})
